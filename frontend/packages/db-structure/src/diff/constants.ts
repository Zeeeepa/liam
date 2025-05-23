export const PATH_PATTERNS = {
  TABLE_BASE: /^\/tables\/([^/]+)$/,
  TABLE_NAME: /^\/tables\/([^/]+)\/name$/,
  TABLE_COMMENT: /^\/tables\/([^/]+)\/comment$/,
  COLUMN_BASE: /^\/tables\/([^/]+)\/columns\/([^/]+)$/,
  COLUMN_NAME: /^\/tables\/([^/]+)\/columns\/([^/]+)\/name$/,
  COLUMN_COMMENT: /^\/tables\/([^/]+)\/columns\/([^/]+)\/comment$/,
  COLUMN_PRIMARY: /^\/tables\/([^/]+)\/columns\/([^/]+)\/primary$/,
  COLUMN_DEFAULT: /^\/tables\/([^/]+)\/columns\/([^/]+)\/default$/,
  COLUMN_CHECK: /^\/tables\/([^/]+)\/columns\/([^/]+)\/check$/,
  COLUMN_UNIQUE: /^\/tables\/([^/]+)\/columns\/([^/]+)\/unique$/,
  COLUMN_NOT_NULL: /^\/tables\/([^/]+)\/columns\/([^/]+)\/notNull$/,
  INDEX_BASE: /^\/tables\/([^/]+)\/indexes\/([^/]+)$/,
  INDEX_NAME: /^\/tables\/([^/]+)\/indexes\/([^/]+)\/name$/,
  INDEX_UNIQUE: /^\/tables\/([^/]+)\/indexes\/([^/]+)\/unique$/,
  INDEX_COLUMNS: /^\/tables\/([^/]+)\/indexes\/([^/]+)\/columns$/,
  INDEX_TYPE: /^\/tables\/([^/]+)\/indexes\/([^/]+)\/type$/,
} as const
