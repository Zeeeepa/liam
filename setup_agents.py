#!/usr/bin/env python3
"""
Liam Setup & Agent Management Script
Consolidates all setup, backup, restore, and configuration functionality
"""

import sys
import os
import subprocess
import json
import argparse
from pathlib import Path
from datetime import datetime
import shutil

class LiamSetup:
    def __init__(self):
        self.project_root = Path(__file__).parent
        self.backup_dir = self.project_root / "backups"
        self.env_file = self.project_root / ".env.local"
        
    def install_dependencies(self):
        """Install all project dependencies"""
        print("📦 Installing dependencies...")
        
        # Install Node.js dependencies
        if not shutil.which("pnpm"):
            print("Installing pnpm...")
            subprocess.run(["npm", "install", "-g", "pnpm"], check=True)
        
        print("Installing Node packages...")
        subprocess.run(["pnpm", "install"], cwd=self.project_root, check=True)
        
        # Install Python dependencies if needed
        if (self.project_root / "requirements.txt").exists():
            print("Installing Python packages...")
            subprocess.run([sys.executable, "-m", "pip", "install", "-r", "requirements.txt"], check=True)
        
        print("✅ Dependencies installed successfully!")
        
    def configure_environment(self):
        """Interactive environment configuration"""
        print("⚙️  Configuring environment...")
        
        if self.env_file.exists():
            response = input(f".env.local already exists. Overwrite? (y/N): ")
            if response.lower() != 'y':
                print("Skipping configuration.")
                return
        
        # Copy template
        env_example = self.project_root / ".env.example"
        if env_example.exists():
            shutil.copy(env_example, self.env_file)
            print(f"✅ Created .env.local from template")
        else:
            # Create basic template
            with open(self.env_file, 'w') as f:
                f.write("# Liam Environment Configuration\n\n")
                f.write("NEXT_PUBLIC_BASE_URL=http://localhost:3001\n")
                f.write("PORT=3001\n")
                f.write("\n# TODO: Add your API keys and database URL\n")
                f.write("OPENAI_API_KEY=\n")
                f.write("POSTGRES_URL=\n")
            print(f"✅ Created basic .env.local")
        
        # Secure file permissions
        os.chmod(self.env_file, 0o600)
        print(f"✅ Secured file permissions (600)")
        
        print("\n⚠️  Please edit .env.local and add your API keys and database URL")
        
    def validate_environment(self):
        """Validate environment configuration"""
        print("🔍 Validating environment...")
        
        if not self.env_file.exists():
            print("❌ .env.local not found. Run: python3 setup_agents.py configure")
            return False
        
        # Load environment
        env_vars = {}
        with open(self.env_file) as f:
            for line in f:
                line = line.strip()
                if line and not line.startswith('#') and '=' in line:
                    key, value = line.split('=', 1)
                    env_vars[key] = value
        
        # Check required variables
        required = [
            'OPENAI_API_KEY',
            'POSTGRES_URL',
            'NEXT_PUBLIC_BASE_URL'
        ]
        
        missing = []
        for var in required:
            if var not in env_vars or not env_vars[var]:
                missing.append(var)
        
        if missing:
            print(f"❌ Missing required variables: {', '.join(missing)}")
            return False
        
        print("✅ Environment configuration valid!")
        return True
        
    def backup_database(self, compress=True, s3_bucket=None, retention_days=30):
        """Backup database"""
        print("💾 Creating database backup...")
        
        # Create backup directory
        self.backup_dir.mkdir(exist_ok=True)
        
        # Get database URL
        env_vars = self._load_env()
        db_url = env_vars.get('POSTGRES_URL')
        if not db_url:
            print("❌ POSTGRES_URL not found in .env.local")
            return False
        
        # Generate backup filename
        timestamp = datetime.now().strftime('%Y-%m-%d-%H-%M')
        backup_file = self.backup_dir / f"backup-{timestamp}.sql"
        
        # Create backup using pg_dump
        print(f"Creating backup: {backup_file}")
        try:
            with open(backup_file, 'w') as f:
                subprocess.run(
                    ['pg_dump', db_url],
                    stdout=f,
                    check=True
                )
            print(f"✅ Backup created: {backup_file}")
            
            # Compress if requested
            if compress:
                print("Compressing backup...")
                subprocess.run(['gzip', str(backup_file)], check=True)
                backup_file = Path(str(backup_file) + '.gz')
                print(f"✅ Compressed: {backup_file}")
            
            # Upload to S3 if configured
            if s3_bucket:
                self._upload_to_s3(backup_file, s3_bucket)
            
            # Clean old backups
            self._cleanup_old_backups(retention_days)
            
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Backup failed: {e}")
            return False
    
    def restore_database(self, backup_file, dry_run=False):
        """Restore database from backup"""
        backup_path = Path(backup_file)
        
        if not backup_path.exists():
            print(f"❌ Backup file not found: {backup_file}")
            return False
        
        if dry_run:
            print(f"🔍 Dry run - would restore from: {backup_path}")
            return True
        
        print(f"⚠️  WARNING: This will overwrite the current database!")
        response = input("Continue? (yes/NO): ")
        if response.lower() != 'yes':
            print("Restore cancelled.")
            return False
        
        # Get database URL
        env_vars = self._load_env()
        db_url = env_vars.get('POSTGRES_URL')
        if not db_url:
            print("❌ POSTGRES_URL not found in .env.local")
            return False
        
        try:
            # Decompress if needed
            if backup_path.suffix == '.gz':
                print("Decompressing backup...")
                subprocess.run(['gunzip', '-k', str(backup_path)], check=True)
                backup_path = backup_path.with_suffix('')
            
            # Restore database
            print(f"Restoring database from {backup_path}...")
            with open(backup_path) as f:
                subprocess.run(
                    ['psql', db_url],
                    stdin=f,
                    check=True
                )
            
            print("✅ Database restored successfully!")
            return True
            
        except subprocess.CalledProcessError as e:
            print(f"❌ Restore failed: {e}")
            return False
    
    def list_backups(self):
        """List available backups"""
        if not self.backup_dir.exists():
            print("No backups found.")
            return
        
        backups = sorted(self.backup_dir.glob("backup-*.sql*"), reverse=True)
        if not backups:
            print("No backups found.")
            return
        
        print("📦 Available backups:")
        for backup in backups:
            size = backup.stat().st_size / (1024 * 1024)  # MB
            print(f"  - {backup.name} ({size:.1f} MB)")
    
    def run_diagnostics(self):
        """Run system diagnostics"""
        print("🔍 Running system diagnostics...\n")
        
        checks = [
            ("Node.js", ["node", "--version"]),
            ("pnpm", ["pnpm", "--version"]),
            ("Docker", ["docker", "--version"]),
            ("PostgreSQL Client", ["psql", "--version"]),
        ]
        
        for name, cmd in checks:
            try:
                result = subprocess.run(cmd, capture_output=True, text=True, check=True)
                version = result.stdout.strip()
                print(f"✅ {name}: {version}")
            except (subprocess.CalledProcessError, FileNotFoundError):
                print(f"❌ {name}: Not installed")
        
        # Check environment
        print(f"\n📄 Environment file: {self.env_file}")
        if self.env_file.exists():
            print(f"   ✅ Exists (permissions: {oct(self.env_file.stat().st_mode)[-3:]})")
        else:
            print(f"   ❌ Not found")
        
        # Check backup directory
        print(f"\n💾 Backup directory: {self.backup_dir}")
        if self.backup_dir.exists():
            backup_count = len(list(self.backup_dir.glob("backup-*.sql*")))
            print(f"   ✅ {backup_count} backups found")
        else:
            print(f"   ⚠️  Not created yet")
    
    def rotate_api_keys(self, provider='all'):
        """Guide for rotating API keys"""
        print(f"🔑 API Key Rotation Guide for: {provider}\n")
        
        providers = {
            'openai': {
                'url': 'https://platform.openai.com/api-keys',
                'env_var': 'OPENAI_API_KEY'
            },
            'anthropic': {
                'url': 'https://console.anthropic.com/',
                'env_var': 'ANTHROPIC_API_KEY'
            }
        }
        
        if provider == 'all':
            targets = providers.items()
        else:
            targets = [(provider, providers[provider])]
        
        for name, info in targets:
            print(f"\n{name.upper()}:")
            print(f"1. Visit: {info['url']}")
            print(f"2. Generate new API key")
            print(f"3. Update .env.local: {info['env_var']}=new-key")
            print(f"4. Restart application")
            print(f"5. Revoke old key after 24 hours")
    
    def _load_env(self):
        """Load environment variables from .env.local"""
        env_vars = {}
        if self.env_file.exists():
            with open(self.env_file) as f:
                for line in f:
                    line = line.strip()
                    if line and not line.startswith('#') and '=' in line:
                        key, value = line.split('=', 1)
                        env_vars[key.strip()] = value.strip()
        return env_vars
    
    def _cleanup_old_backups(self, retention_days):
        """Remove backups older than retention period"""
        if not self.backup_dir.exists():
            return
        
        import time
        cutoff = time.time() - (retention_days * 24 * 60 * 60)
        
        for backup in self.backup_dir.glob("backup-*.sql*"):
            if backup.stat().st_mtime < cutoff:
                print(f"Removing old backup: {backup.name}")
                backup.unlink()
    
    def _upload_to_s3(self, file_path, bucket):
        """Upload backup to S3"""
        print(f"Uploading to S3: s3://{bucket}/{file_path.name}")
        try:
            subprocess.run([
                'aws', 's3', 'cp',
                str(file_path),
                f's3://{bucket}/{file_path.name}'
            ], check=True)
            print(f"✅ Uploaded to S3")
        except subprocess.CalledProcessError as e:
            print(f"❌ S3 upload failed: {e}")

def main():
    parser = argparse.ArgumentParser(description='Liam Setup & Agent Management')
    subparsers = parser.add_subparsers(dest='command', help='Command to run')
    
    # Install command
    subparsers.add_parser('install', help='Install dependencies')
    
    # Configure command
    subparsers.add_parser('configure', help='Configure environment')
    
    # Validate command
    subparsers.add_parser('validate-env', help='Validate environment configuration')
    
    # Backup command
    backup_parser = subparsers.add_parser('backup', help='Database backup operations')
    backup_subparsers = backup_parser.add_subparsers(dest='backup_action')
    
    backup_now = backup_subparsers.add_parser('now', help='Create backup now')
    backup_now.add_argument('--compress', action='store_true', help='Compress backup')
    backup_now.add_argument('--s3-bucket', help='Upload to S3 bucket')
    backup_now.add_argument('--retention', type=int, default=30, help='Retention days')
    
    backup_subparsers.add_parser('list', help='List backups')
    
    # Restore command
    restore_parser = subparsers.add_parser('restore', help='Restore database')
    restore_parser.add_argument('--file', required=True, help='Backup file to restore')
    restore_parser.add_argument('--dry-run', action='store_true', help='Test without restoring')
    
    # Diagnostics command
    subparsers.add_parser('doctor', help='Run system diagnostics')
    
    # Rotate keys command
    rotate_parser = subparsers.add_parser('rotate-keys', help='Guide for rotating API keys')
    rotate_parser.add_argument('--provider', default='all', choices=['all', 'openai', 'anthropic'])
    
    args = parser.parse_args()
    
    if not args.command:
        parser.print_help()
        return
    
    setup = LiamSetup()
    
    if args.command == 'install':
        setup.install_dependencies()
    elif args.command == 'configure':
        setup.configure_environment()
    elif args.command == 'validate-env':
        setup.validate_environment()
    elif args.command == 'backup':
        if args.backup_action == 'now':
            setup.backup_database(
                compress=args.compress,
                s3_bucket=args.s3_bucket,
                retention_days=args.retention
            )
        elif args.backup_action == 'list':
            setup.list_backups()
        else:
            backup_parser.print_help()
    elif args.command == 'restore':
        setup.restore_database(args.file, dry_run=args.dry_run)
    elif args.command == 'doctor':
        setup.run_diagnostics()
    elif args.command == 'rotate-keys':
        setup.rotate_api_keys(args.provider)

if __name__ == '__main__':
    main()
