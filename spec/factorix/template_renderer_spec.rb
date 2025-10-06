# frozen_string_literal: true

require "pathname"
require "spec_helper"
require "tmpdir"

RSpec.describe Factorix::TemplateRenderer do
  subject(:renderer) { Factorix::TemplateRenderer.new(template_dir, output_dir) }

  around do |example|
    Dir.mktmpdir do |tmpdir|
      @tmpdir = Pathname(tmpdir)
      @template_dir = @tmpdir / "templates"
      @output_dir = @tmpdir / "output"
      @template_dir.mkpath
      @output_dir.mkpath
      example.run
    end
  end

  let(:template_dir) { @template_dir }
  let(:output_dir) { @output_dir }

  describe "#render" do
    context "with simple template" do
      before do
        template_content = "Hello <%= name %>!"
        (template_dir / "greeting.erb").write(template_content)
      end

      it "renders template with variables" do
        renderer.render("greeting.erb", "greeting.txt", name: "World")

        output_file = output_dir / "greeting.txt"
        expect(output_file).to exist
        expect(output_file.read).to eq("Hello World!")
      end
    end

    context "with complex template" do
      before do
        template_content = <<~ERB
          {
            "name": "<%= mod_name %>",
            "version": "<%= version %>",
            "author": "<%= author %>"
          }
        ERB
        (template_dir / "info.json.erb").write(template_content)
      end

      it "renders JSON template with multiple variables" do
        renderer.render(
          "info.json.erb",
          "info.json",
          mod_name: "test-mod",
          version: "1.0.0",
          author: "Test Author"
        )

        output_file = output_dir / "info.json"
        content = JSON.parse(output_file.read)
        expect(content["name"]).to eq("test-mod")
        expect(content["version"]).to eq("1.0.0")
        expect(content["author"]).to eq("Test Author")
      end
    end

    context "with nested output directory" do
      before do
        template_content = "Nested file content"
        (template_dir / "nested.erb").write(template_content)
      end

      it "creates nested output directories" do
        renderer.render("nested.erb", "deeply/nested/file.txt")

        output_file = output_dir / "deeply" / "nested" / "file.txt"
        expect(output_file).to exist
        expect(output_file.read).to eq("Nested file content")
      end
    end

    context "with non-existent template" do
      it "raises FileNotFoundError" do
        expect {
          renderer.render("non_existent.erb", "output.txt")
        }.to raise_error(Factorix::FileNotFoundError, /Template file not found/)
      end
    end
  end
end
