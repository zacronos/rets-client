import { RetsContext, IHeaderInfo, IRetsQueryOptions } from './client'
export interface IRetsError {
  replyTag: string
  replyCode: string
  replyText: string
}
export class RetsError extends Error implements IRetsError, Partial<RetsContext> {
  replyTag: string
  replyCode: string
  replyText: string

  headerInfo?: IHeaderInfo
  retsMethod?: 'search'
  queryOptions?: IRetsQueryOptions
}

export class RetsParamError extends RetsError { }
export class RetsServerError extends RetsError {
  constructor(retsContext: RetsContext, replyCode?: any, replyText?: string)  
}
export class RetsReplyError extends RetsError {
  constructor(retsContext: RetsContext, replyCode?: any, replyText?: string)
}
/**
 * This error can raise with sourceError: "Unexpected end of xml stream"
 * It inherits from Bluebird OperationalError, but the { cause } property not set
 */
export class RetsProcessingError extends RetsError {
  constructor(retsContext: RetsContext, message?: string)

  isOperational: boolean
  sourceError: string
}
export class RetsPermissionError extends RetsError { }