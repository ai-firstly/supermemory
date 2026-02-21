# frozen_string_literal: true

module Supermemory
  module Resources
    class Search < Base
      # Search documents (v3 API)
      # @param q [String] Search query
      # @param chunk_threshold [Float, nil] 0 (most results) to 1 (most precise)
      # @param doc_id [String, nil] Limit search to a specific document
      # @param filters [Hash, nil] Filter expression
      # @param include_full_docs [Boolean] Include full document content
      # @param include_summary [Boolean] Include document summaries
      # @param limit [Integer, nil] Max results
      # @param only_matching_chunks [Boolean] Skip surrounding context chunks
      # @param rerank [Boolean] Rerank results by relevance
      # @param rewrite_query [Boolean] LLM query rewrite (~400ms extra latency)
      # @return [Hash] { "results" => [...], "timing" => ..., "total" => ... }
      def documents(q:, chunk_threshold: nil, doc_id: nil, filters: nil,
                    include_full_docs: false, include_summary: false,
                    limit: nil, only_matching_chunks: false,
                    rerank: false, rewrite_query: false)
        body = { q: q }
        body[:chunkThreshold] = chunk_threshold if chunk_threshold
        body[:docId] = doc_id if doc_id
        body[:filters] = filters if filters
        body[:includeFullDocs] = include_full_docs if include_full_docs
        body[:includeSummary] = include_summary if include_summary
        body[:limit] = limit if limit
        body[:onlyMatchingChunks] = only_matching_chunks if only_matching_chunks
        body[:rerank] = rerank if rerank
        body[:rewriteQuery] = rewrite_query if rewrite_query
        client.post("/v3/search", body)
      end

      # Alias for documents search
      # @see #documents
      def execute(**params)
        documents(**params)
      end

      # Search memories (v4 API - lower latency, conversational use)
      # @param q [String] Search query
      # @param container_tag [String, nil] Scope to a container
      # @param filters [Hash, nil] Filter expression
      # @param include [Hash, nil] Control included fields
      # @param limit [Integer, nil] Max results
      # @param rerank [Boolean] Rerank results
      # @param rewrite_query [Boolean] LLM query rewrite
      # @param search_mode [String, nil] "memories", "hybrid", or "documents"
      # @param threshold [Float, nil] Score threshold (0 to 1)
      # @return [Hash] { "results" => [...], "timing" => ..., "total" => ... }
      def memories(q:, container_tag: nil, filters: nil, include: nil,
                   limit: nil, rerank: false, rewrite_query: false,
                   search_mode: nil, threshold: nil)
        body = { q: q }
        body[:containerTag] = container_tag if container_tag
        body[:filters] = filters if filters
        body[:include] = include if include
        body[:limit] = limit if limit
        body[:rerank] = rerank if rerank
        body[:rewriteQuery] = rewrite_query if rewrite_query
        body[:searchMode] = search_mode if search_mode
        body[:threshold] = threshold if threshold
        client.post("/v4/search", body)
      end
    end
  end
end
