import { IQueryOptions, IRetsStream, IQueryResponse } from './client'

export interface IClientSearch {
    stream: {
      /**
       * headerInfo []
       * data [result]
       */
      query (
        resourceType: string,
        classType: string,
        query: string,
        options?: IQueryOptions,
        rawData?: boolean,
        parserEncoding?: string): {
          retsStream: IRetsStream
        }
    }
    /**
     * perform a query using DMQL2 -- pass resource, class, and query, and options
     */
    query (resourceType: string, classType: string, query: string, options?: IQueryOptions, parserEncoding?: string): Promise<IQueryResponse>
}