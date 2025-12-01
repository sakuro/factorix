# frozen_string_literal: true

RSpec.describe Factorix::MODInstallationState do
  let(:mod_list_path) { Pathname("/fake/path/mod-list.json") }
  let(:state) { Factorix::MODInstallationState.new(mod_list_path:) }

  let(:mod_list) { instance_double(Factorix::MODList) }
  let(:installed_mods) { [] }
  let(:graph) { instance_double(Factorix::Dependency::Graph) }
  let(:presenter) { instance_double(Factorix::Progress::Presenter) }
  let(:handler) { instance_double(Factorix::Progress::ScanHandler) }

  before do
    allow(Factorix::MODList).to receive(:load).with(mod_list_path).and_return(mod_list)
    allow(Factorix::Progress::Presenter).to receive(:new).and_return(presenter)
    allow(Factorix::Progress::ScanHandler).to receive(:new).with(presenter).and_return(handler)
    allow(Factorix::InstalledMOD).to receive(:all).with(handler:).and_return(installed_mods)
    allow(Factorix::Dependency::Graph::Builder).to receive(:build)
      .with(installed_mods:, mod_list:)
      .and_return(graph)
  end

  describe "#mod_list" do
    it "loads mod-list.json" do
      expect(state.mod_list).to eq(mod_list)
    end

    it "caches the result" do
      state.mod_list
      state.mod_list

      expect(Factorix::MODList).to have_received(:load).once
    end
  end

  describe "#installed_mods" do
    it "scans all installed MODs" do
      expect(state.installed_mods).to eq(installed_mods)
    end

    it "caches the result" do
      state.installed_mods
      state.installed_mods

      expect(Factorix::InstalledMOD).to have_received(:all).once
    end
  end

  describe "#graph" do
    it "builds dependency graph from installed_mods and mod_list" do
      expect(state.graph).to eq(graph)
    end

    it "caches the result" do
      state.graph
      state.graph

      expect(Factorix::Dependency::Graph::Builder).to have_received(:build).once
    end

    it "triggers loading of mod_list and installed_mods" do
      state.graph

      expect(Factorix::MODList).to have_received(:load)
      expect(Factorix::InstalledMOD).to have_received(:all)
    end
  end
end
