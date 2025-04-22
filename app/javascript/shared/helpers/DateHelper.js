import fromUnixTime from 'date-fns/fromUnixTime';
import format from 'date-fns/format';
import isToday from 'date-fns/isToday';
import isYesterday from 'date-fns/isYesterday';
import { endOfDay, getUnixTime, startOfDay, differenceInDays } from 'date-fns';
import { zonedTimeToUtc, utcToZonedTime } from 'date-fns-tz';

// Define o fuso horário padrão para Brasília (UTC-3)
export const DEFAULT_TIMEZONE = 'America/Sao_Paulo';

// Função de utilidade para converter datas para o fuso horário de Brasília
export const toBrasiliaTime = date => {
  return utcToZonedTime(date, DEFAULT_TIMEZONE);
};

// Função de utilidade para converter datas de Brasília para UTC
export const fromBrasiliaTime = date => {
  return zonedTimeToUtc(date, DEFAULT_TIMEZONE);
};

export const formatUnixDate = (date, dateFormat = 'MMM dd, yyyy') => {
  const unixDate = fromUnixTime(date);
  // Converte para o fuso horário de Brasília antes de formatar
  const brasiliaDate = toBrasiliaTime(unixDate);
  return format(brasiliaDate, dateFormat);
};

export const formatDate = ({ date, todayText, yesterdayText }) => {
  const dateValue = new Date(date);
  // Converte para o fuso horário de Brasília para comparações
  const brasiliaDate = toBrasiliaTime(dateValue);
  if (isToday(brasiliaDate)) return todayText;
  if (isYesterday(brasiliaDate)) return yesterdayText;
  return date;
};

export const formatDigitToString = val => {
  return val > 9 ? `${val}` : `0${val}`;
};

export const isTimeAfter = (h1, m1, h2, m2) => {
  if (h1 < h2) {
    return false;
  }

  if (h1 === h2) {
    return m1 >= m2;
  }

  return true;
};

/** Get start of day as a UNIX timestamp */
export const getUnixStartOfDay = date => {
  // Converte para o fuso horário de Brasília antes de obter o início do dia
  const brasiliaDate = toBrasiliaTime(date);
  return getUnixTime(startOfDay(brasiliaDate));
};

/** Get end of day as a UNIX timestamp */
export const getUnixEndOfDay = date => {
  // Converte para o fuso horário de Brasília antes de obter o fim do dia
  const brasiliaDate = toBrasiliaTime(date);
  return getUnixTime(endOfDay(brasiliaDate));
};

export const generateRelativeTime = (value, unit, languageCode) => {
  const code = languageCode?.replace(/_/g, '-'); // Hacky fix we need to handle it from source
  const rtf = new Intl.RelativeTimeFormat(code, {
    numeric: 'auto',
  });
  return rtf.format(value, unit);
};

export const getDayDifferenceFromNow = (now, timestampInSeconds) => {
  const date = new Date(timestampInSeconds * 1000);
  // Converte ambas as datas para o fuso horário de Brasília antes de calcular a diferença
  const brasiliaNow = toBrasiliaTime(now);
  const brasiliaDate = toBrasiliaTime(date);
  return differenceInDays(brasiliaNow, brasiliaDate);
};
