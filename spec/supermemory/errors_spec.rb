# frozen_string_literal: true

RSpec.describe Supermemory::APIError do
  it "stores status, body, and headers" do
    error = described_class.new("test error", status: 400, body: { "error" => "bad" }, headers: { "x-id" => "123" })
    expect(error.status).to eq(400)
    expect(error.body).to eq({ "error" => "bad" })
    expect(error.headers).to eq({ "x-id" => "123" })
    expect(error.message).to eq("test error")
  end

  it "uses default message when none provided" do
    error = described_class.new(status: 500)
    expect(error.message).to eq("API error (status: 500)")
  end
end

RSpec.describe Supermemory::AuthenticationError do
  it "defaults to status 401" do
    error = described_class.new("Unauthorized")
    expect(error.status).to eq(401)
  end
end

RSpec.describe Supermemory::RateLimitError do
  it "defaults to status 429" do
    error = described_class.new("Too many requests")
    expect(error.status).to eq(429)
  end
end

RSpec.describe Supermemory::NotFoundError do
  it "defaults to status 404" do
    error = described_class.new
    expect(error.status).to eq(404)
  end
end

RSpec.describe Supermemory::BadRequestError do
  it "defaults to status 400" do
    error = described_class.new
    expect(error.status).to eq(400)
  end
end

RSpec.describe Supermemory::InternalServerError do
  it "defaults to status 500" do
    error = described_class.new
    expect(error.status).to eq(500)
  end
end

RSpec.describe Supermemory::APIConnectionError do
  it "is a subclass of Error" do
    expect(described_class.superclass).to eq(Supermemory::Error)
  end
end

RSpec.describe Supermemory::APITimeoutError do
  it "is a subclass of APIConnectionError" do
    expect(described_class.superclass).to eq(Supermemory::APIConnectionError)
  end
end

RSpec.describe "ERROR_MAP" do
  it "maps status codes to error classes" do
    expect(Supermemory::ERROR_MAP[400]).to eq(Supermemory::BadRequestError)
    expect(Supermemory::ERROR_MAP[401]).to eq(Supermemory::AuthenticationError)
    expect(Supermemory::ERROR_MAP[403]).to eq(Supermemory::PermissionDeniedError)
    expect(Supermemory::ERROR_MAP[404]).to eq(Supermemory::NotFoundError)
    expect(Supermemory::ERROR_MAP[409]).to eq(Supermemory::ConflictError)
    expect(Supermemory::ERROR_MAP[422]).to eq(Supermemory::UnprocessableEntityError)
    expect(Supermemory::ERROR_MAP[429]).to eq(Supermemory::RateLimitError)
  end
end
