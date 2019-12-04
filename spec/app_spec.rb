# frozen_string_literal: true

require "spec_helper"

class Logger
  # TODO: figure out how to properly use class double for this.
  # (was taking me too long).
  def flush() end
end

describe Tulle do
  let(:app) { Tulle.new }

  context "GET to /" do
    let(:response) { get "/" }

    it "returns status 200 OK" do
      expect(response.status).to eq 200
    end
  end

  context "GET to /stats" do
    let(:response) { get "/stats" }

    it "returns status 200 OK" do
      expect(response.status).to eq 200
    end
  end

  context "GET to /err" do
    let(:response) { get "/err" }

    it "returns status 200 OK" do
      expect(response.status).to eq 200
    end
  end

  context "GET to /*/err" do
    let(:response) { get "/foo/err" }

    it "returns status 200 OK" do
      expect(response.status).to eq 200
    end
  end

  context "GET to /patroninfo" do
    let(:response) { get "/patroninfo" }

    it "returns status 301 OK" do
      expect(response.status).to eq 301
    end
  end

  context "GET to  @@DIAMOND_PATH" do
    let(:response) { get "/record=foo" }

    it "returns status 200 OK" do
      expect(response.status).to eq 301
    end
  end

  context "GET to  /*" do
    let(:response) { get "/foo" }

    it "returns status 302 OK" do
      expect(response.status).to eq 302
    end
  end
end
