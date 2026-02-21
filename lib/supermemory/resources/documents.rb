# frozen_string_literal: true

module Supermemory
  module Resources
    class Documents < Base
      # Add a document
      # @param content [String] Text, URL, PDF, image, or video content
      # @param container_tag [String, nil] Container tag (max 100 chars)
      # @param custom_id [String, nil] Custom identifier (max 100 chars)
      # @param entity_context [String, nil] Context to guide memory extraction (max 1500 chars)
      # @param metadata [Hash, nil] Key-value metadata
      # @return [Hash] { "id" => "...", "status" => "..." }
      def add(content:, container_tag: nil, custom_id: nil, entity_context: nil, metadata: nil)
        body = { content: content }
        body[:containerTag] = container_tag if container_tag
        body[:customId] = custom_id if custom_id
        body[:entityContext] = entity_context if entity_context
        body[:metadata] = metadata if metadata
        client.post("/v3/documents", body)
      end

      # Batch add documents
      # @param documents [Array<Hash>, Array<String>] Array of document objects or content strings
      # @param container_tag [String, nil] Applied to all documents
      # @param metadata [Hash, nil] Applied to all documents
      # @return [Array<Hash>] Array of { "id" => "...", "status" => "..." }
      def batch_add(documents:, container_tag: nil, metadata: nil)
        body = { documents: documents }
        body[:containerTag] = container_tag if container_tag
        body[:metadata] = metadata if metadata
        client.post("/v3/documents/batch", body)
      end

      # Get a document by ID
      # @param id [String] Document ID
      # @return [Hash] Full document object
      def get(id)
        client.get("/v3/documents/#{id}")
      end

      # Update a document
      # @param id [String] Document ID
      # @param options [Hash] Fields to update (content, container_tag, custom_id, metadata)
      # @return [Hash] { "id" => "...", "status" => "..." }
      def update(id, **options)
        body = {}
        body[:content] = options[:content] if options.key?(:content)
        body[:containerTag] = options[:container_tag] if options.key?(:container_tag)
        body[:customId] = options[:custom_id] if options.key?(:custom_id)
        body[:metadata] = options[:metadata] if options.key?(:metadata)
        client.patch("/v3/documents/#{id}", body)
      end

      # Delete a document
      # @param id [String] Document ID
      # @return [nil]
      def delete(id)
        client.delete("/v3/documents/#{id}")
        nil
      end

      # List documents
      # @param filters [Hash, nil] Filter expression ({ "AND" => [...] } or { "OR" => [...] })
      # @param include_content [Boolean] Include document content in response
      # @param limit [Integer, nil] Results per page
      # @param page [Integer, nil] Page number
      # @param sort [String, nil] Sort field ("createdAt" or "updatedAt")
      # @param order [String, nil] Sort order ("asc" or "desc")
      # @return [Hash] { "memories" => [...], "pagination" => { ... } }
      def list(filters: nil, include_content: false, limit: nil, page: nil, sort: nil, order: nil)
        body = {}
        body[:filters] = filters if filters
        body[:includeContent] = include_content if include_content
        body[:limit] = limit if limit
        body[:page] = page if page
        body[:sort] = sort if sort
        body[:order] = order if order
        client.post("/v3/documents/list", body)
      end

      # Bulk delete documents
      # @param ids [Array<String>, nil] Document IDs to delete (max 100)
      # @param container_tags [Array<String>, nil] Delete all docs in these containers
      # @return [Hash] { "deletedCount" => ..., "success" => true/false }
      def delete_bulk(ids: nil, container_tags: nil)
        body = {}
        body[:ids] = ids if ids
        body[:containerTags] = container_tags if container_tags
        client.delete("/v3/documents/bulk", body)
      end

      # List documents currently processing
      # @return [Hash] { "documents" => [...], "totalCount" => ... }
      def list_processing
        client.get("/v3/documents/processing")
      end

      # Upload a file
      # @param file [Faraday::Multipart::FilePart, IO] File to upload
      # @param file_type [String, nil] Override file type detection
      # @param mime_type [String, nil] Required for image/video file types
      # @param metadata [Hash, nil] Metadata as a hash (will be JSON-encoded)
      # @param container_tag [String, nil] Container tag
      # @return [Hash] { "id" => "...", "status" => "..." }
      def upload_file(file:, file_type: nil, mime_type: nil, metadata: nil, container_tag: nil)
        body = { file: file }
        body[:fileType] = file_type if file_type
        body[:mimeType] = mime_type if mime_type
        body[:metadata] = metadata.to_json if metadata
        body[:containerTags] = container_tag if container_tag
        client.multipart_post("/v3/documents/file", body)
      end
    end
  end
end
