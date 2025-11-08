#!/usr/bin/env python3
"""
Liam Start & Monitoring Script
Consolidates all deployment, health check, and monitoring functionality
"""

import sys
import os
import subprocess
import json
import argparse
import time
import signal
from pathlib import Path
from datetime import datetime
import http.client

class LiamStart:
    def __init__(self):
        self.project_root = Path(__file__).parent
        self.env_file = self.project_root / ".env.local"
        self.port = 3001
        self.process = None
        
    def start(self, method='traditional'):
        """Start the application"""
        print(f"🚀 Starting Liam ({method})...")
        
        if method == 'docker':
            return self.start_docker()
        elif method == 'kubernetes':
            return self.start_kubernetes()
        elif method == 'traditional':
            return self.start_traditional()
        else:
            print(f"❌ Unknown method: {method}")
            return False
    
    def start_docker(self):
        """Start with Docker Compose"""
        print("🐳 Starting with Docker Compose...")
        
        if not Path('docker-compose.yml').exists():
            print("❌ docker-compose.yml not found")
            return False
        
        try:
            subprocess.run(['docker-compose', 'up', '-d'], check=True)
            print("✅ Docker containers started")
            
            # Wait for health check
            self.wait_for_health()
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Docker start failed: {e}")
            return False
    
    def start_traditional(self):
        """Start with Node.js/pnpm"""
        print("📦 Starting with Node.js...")
        
        try:
            # Build if needed
            if not Path('frontend/apps/app/.next').exists():
                print("Building application...")
                subprocess.run(['pnpm', 'build', '--filter', '@liam-hq/app'], check=True)
            
            # Start with PM2 if available
            if subprocess.run(['which', 'pm2'], capture_output=True).returncode == 0:
                print("Starting with PM2...")
                subprocess.run([
                    'pm2', 'start', 'pnpm',
                    '--name', 'liam',
                    '--', 'start', '--filter', '@liam-hq/app'
                ], check=True)
                subprocess.run(['pm2', 'save'], check=True)
            else:
                print("Starting with pnpm...")
                subprocess.Popen(['pnpm', 'start', '--filter', '@liam-hq/app'])
            
            print("✅ Application started")
            self.wait_for_health()
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Start failed: {e}")
            return False
    
    def start_kubernetes(self):
        """Deploy to Kubernetes"""
        print("☸️  Deploying to Kubernetes...")
        
        try:
            # Apply Kubernetes manifests
            subprocess.run(['kubectl', 'apply', '-f', 'k8s/', '--namespace=liam'], check=True)
            print("✅ Kubernetes deployment created")
            
            # Wait for pods
            print("Waiting for pods to be ready...")
            subprocess.run([
                'kubectl', 'wait', '--for=condition=ready',
                'pod', '-l', 'app=liam',
                '--timeout=300s',
                '--namespace=liam'
            ], check=True)
            
            print("✅ Kubernetes deployment ready")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Kubernetes deployment failed: {e}")
            return False
    
    def stop(self, method='traditional'):
        """Stop the application"""
        print(f"🛑 Stopping Liam ({method})...")
        
        if method == 'docker':
            return self.stop_docker()
        elif method == 'traditional':
            return self.stop_traditional()
        else:
            print(f"❌ Unknown method: {method}")
            return False
    
    def stop_docker(self):
        """Stop Docker containers"""
        try:
            subprocess.run(['docker-compose', 'down'], check=True)
            print("✅ Docker containers stopped")
            return True
        except subprocess.CalledProcessError as e:
            print(f"❌ Docker stop failed: {e}")
            return False
    
    def stop_traditional(self):
        """Stop Node.js application"""
        try:
            if subprocess.run(['which', 'pm2'], capture_output=True).returncode == 0:
                subprocess.run(['pm2', 'stop', 'liam'], check=False)
                subprocess.run(['pm2', 'delete', 'liam'], check=False)
            print("✅ Application stopped")
            return True
        except Exception as e:
            print(f"❌ Stop failed: {e}")
            return False
    
    def restart(self, method='traditional'):
        """Restart the application"""
        print("🔄 Restarting Liam...")
        self.stop(method)
        time.sleep(2)
        return self.start(method)
    
    def status(self):
        """Check application status"""
        print("📊 Checking Liam status...")
        
        # Check health endpoint
        health = self.check_health()
        if health:
            print(f"✅ Application: Running")
            print(f"   Status: {health.get('status', 'unknown')}")
            print(f"   Uptime: {health.get('uptime', 0)} seconds")
        else:
            print("❌ Application: Not running or unhealthy")
        
        # Check database
        ready = self.check_ready()
        if ready:
            print(f"✅ Database: {ready.get('database', 'unknown')}")
        
        # Check Docker containers if applicable
        try:
            result = subprocess.run(
                ['docker-compose', 'ps'],
                capture_output=True,
                text=True,
                check=False
            )
            if result.returncode == 0 and result.stdout.strip():
                print(f"\n🐳 Docker Containers:")
                print(result.stdout)
        except FileNotFoundError:
            pass
    
    def logs(self, follow=False, lines=100):
        """View application logs"""
        print(f"📝 Viewing logs (last {lines} lines)...")
        
        try:
            # Try PM2 logs first
            if subprocess.run(['which', 'pm2'], capture_output=True).returncode == 0:
                cmd = ['pm2', 'logs', 'liam']
                if not follow:
                    cmd.extend(['--lines', str(lines), '--nostream'])
                subprocess.run(cmd)
            # Try Docker logs
            elif Path('docker-compose.yml').exists():
                cmd = ['docker-compose', 'logs']
                if follow:
                    cmd.append('-f')
                else:
                    cmd.extend(['--tail', str(lines)])
                cmd.append('app')
                subprocess.run(cmd)
            else:
                print("⚠️  No logs available")
        except KeyboardInterrupt:
            print("\n👋 Stopped viewing logs")
    
    def monitor(self, interval=60):
        """Monitor application health"""
        print(f"📊 Monitoring Liam (interval: {interval}s)")
        print("Press Ctrl+C to stop\n")
        
        try:
            while True:
                timestamp = datetime.now().strftime('%Y-%m-%d %H:%M:%S')
                
                health = self.check_health()
                metrics = self.check_metrics()
                
                if health:
                    status_icon = "✅"
                    memory = metrics.get('memory', {}).get('used', 'N/A') if metrics else 'N/A'
                    uptime = health.get('uptime', 0)
                    
                    # Convert uptime to readable format
                    hours = uptime // 3600
                    minutes = (uptime % 3600) // 60
                    uptime_str = f"{hours}h {minutes}m"
                    
                    print(f"[{timestamp}] {status_icon} Health: OK | Memory: {memory} | Uptime: {uptime_str}")
                else:
                    print(f"[{timestamp}] ❌ Health: FAIL")
                
                time.sleep(interval)
        except KeyboardInterrupt:
            print("\n👋 Stopped monitoring")
    
    def check_health(self):
        """Check /api/health endpoint"""
        try:
            conn = http.client.HTTPConnection('localhost', self.port, timeout=5)
            conn.request('GET', '/api/health')
            response = conn.getresponse()
            if response.status == 200:
                data = json.loads(response.read().decode())
                return data
        except Exception:
            pass
        return None
    
    def check_ready(self):
        """Check /api/ready endpoint"""
        try:
            conn = http.client.HTTPConnection('localhost', self.port, timeout=5)
            conn.request('GET', '/api/ready')
            response = conn.getresponse()
            if response.status == 200:
                data = json.loads(response.read().decode())
                return data
        except Exception:
            pass
        return None
    
    def check_metrics(self):
        """Check /api/metrics endpoint"""
        try:
            conn = http.client.HTTPConnection('localhost', self.port, timeout=5)
            conn.request('GET', '/api/metrics')
            response = conn.getresponse()
            if response.status == 200:
                data = json.loads(response.read().decode())
                return data
        except Exception:
            pass
        return None
    
    def wait_for_health(self, max_attempts=30):
        """Wait for application to be healthy"""
        print("⏳ Waiting for application to be ready...")
        
        for i in range(max_attempts):
            health = self.check_health()
            if health:
                print("✅ Application is healthy!")
                return True
            time.sleep(2)
            print(f"   Attempt {i+1}/{max_attempts}...")
        
        print("❌ Application did not become healthy")
        return False
    
    def debug(self):
        """Start in debug mode"""
        print("🐛 Starting in debug mode...")
        
        env = os.environ.copy()
        env['NODE_ENV'] = 'development'
        env['DEBUG'] = '*'
        
        try:
            subprocess.run(
                ['pnpm', 'dev', '--filter', '@liam-hq/app'],
                env=env
            )
        except KeyboardInterrupt:
            print("\n👋 Debug mode stopped")

def main():
    parser = argparse.ArgumentParser(description='Liam Start & Monitoring')
    subparsers = parser.add_subparsers(dest='command', help='Command to run')
    
    # Start command
    start_parser = subparsers.add_parser('start', help='Start application')
    start_parser.add_argument('method', nargs='?', default='traditional',
                             choices=['traditional', 'docker', 'kubernetes'],
                             help='Deployment method')
    
    # Stop command
    stop_parser = subparsers.add_parser('stop', help='Stop application')
    stop_parser.add_argument('method', nargs='?', default='traditional',
                            choices=['traditional', 'docker'],
                            help='Deployment method')
    
    # Restart command
    restart_parser = subparsers.add_parser('restart', help='Restart application')
    restart_parser.add_argument('method', nargs='?', default='traditional',
                               choices=['traditional', 'docker'],
                               help='Deployment method')
    
    # Status command
    subparsers.add_parser('status', help='Check application status')
    
    # Logs command
    logs_parser = subparsers.add_parser('logs', help='View logs')
    logs_parser.add_argument('-f', '--follow', action='store_true', help='Follow logs')
    logs_parser.add_argument('-n', '--lines', type=int, default=100, help='Number of lines')
    
    # Monitor command
    monitor_parser = subparsers.add_parser('monitor', help='Monitor application')
    monitor_parser.add_argument('--interval', type=int, default=60, help='Check interval in seconds')
    
    # Debug command
    subparsers.add_parser('debug', help='Start in debug mode')
    
    args = parser.parse_args()
    
    # Default to start if no command
    if not args.command:
        args.command = 'start'
        args.method = 'traditional'
    
    liam = LiamStart()
    
    if args.command == 'start':
        liam.start(args.method)
    elif args.command == 'stop':
        liam.stop(args.method)
    elif args.command == 'restart':
        liam.restart(args.method)
    elif args.command == 'status':
        liam.status()
    elif args.command == 'logs':
        liam.logs(follow=args.follow, lines=args.lines)
    elif args.command == 'monitor':
        liam.monitor(interval=args.interval)
    elif args.command == 'debug':
        liam.debug()

if __name__ == '__main__':
    main()
