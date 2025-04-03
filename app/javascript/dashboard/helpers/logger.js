/* eslint-disable default-case */
/* eslint-disable no-console */
/* eslint-disable no-underscore-dangle */
export const LogLevel = {
  DEBUG: 0,
  INFO: 1,
  WARN: 2,
  ERROR: 3,
};

// Configuração global
const config = {
  enabled: true,
  minLevel: LogLevel.DEBUG, // Altere para controlar nível de log
  prefix: 'WebPhone',
};

export const Logger = {
  debug(message, data) {
    this._log(LogLevel.DEBUG, message, data);
  },

  info(message, data) {
    this._log(LogLevel.INFO, message, data);
  },

  warn(message, data) {
    this._log(LogLevel.WARN, message, data);
  },

  error(message, data) {
    this._log(LogLevel.ERROR, message, data);
  },

  _log(level, message, data) {
    if (!config.enabled || level < config.minLevel) return;

    const timestamp = new Date().toISOString();
    const prefix = `[${config.prefix}] [${timestamp}]`;

    switch (level) {
      case LogLevel.DEBUG:
        console.debug(`${prefix} 🔍 ${message}`, data || '');
        break;
      case LogLevel.INFO:
        console.info(`${prefix} ℹ️ ${message}`, data || '');
        break;
      case LogLevel.WARN:
        console.warn(`${prefix} ⚠️ ${message}`, data || '');
        break;
      case LogLevel.ERROR:
        console.error(`${prefix} 🛑 ${message}`, data || '');
        break;
    }
  },

  // Configuração
  configure(options) {
    Object.assign(config, options);
  },

  // Desativar temporariamente
  disable() {
    config.enabled = false;
  },

  // Reativar
  enable() {
    config.enabled = true;
  },
};
