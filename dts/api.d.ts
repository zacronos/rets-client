import { RetsError, RetsParamError, RetsServerError, RetsProcessingError, RetsReplyError } from './errors'
import { IGetAutoLogoutClient, Client } from './client'
export const getAutoLogoutClient: IGetAutoLogoutClient
export const getReplyTag: any
export { 
  Client,
  RetsError,
  RetsReplyError,
  RetsServerError,
  RetsProcessingError,
  RetsParamError
}