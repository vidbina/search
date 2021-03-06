require 'spec_helper'

describe 'Searchability' do
  before(:each) do
    stub_class 'City', ActiveRecord::Base
    Chewy.root_strategy = :urgent
    class_double(City).as_stubbed_const
  end

  context 'on a dummy model' do
    before(:each) do
      City.class_eval do
        # TODO: make this obsolete by extending ActiveRecord in an ActiveSupport#on_load block
        include Searchengine::Concerns::Models::Searchable
        extend Chewy::Type::Observe::ActiveRecordMethods
      end
      allow(City).to receive(:set) { |name, val|
        stub_const "Searchengine::Indices::#{name}", val
      }
    end

    it 'exposes the searchability descriptors' do
      expect(City).to respond_to(:searchable_as)
      expect(City).to respond_to(:searchable)
    end

    it 'exposes the Chewy indexing handler' do
      expect(City).to respond_to(:update_index)
    end

    it 'creates a search index for searchable models' do
      expect{
        City.searchable { }
      }.to change{
        Searchengine::Indices.all.count
      }.by(1)
    end

    it 'creates a search index for named searchable models' do
      expect {
        City.searchable_as('Unoccupied') do |index| 
          index.define_type 'Something' do |type|
            type.field :name, :string
          end
        end
      }.to change{
        Searchengine::Indices.all.count
      }.by(1)
    end

    it 'is oblivious to non searchengine indices' do
      expect{
        stub_const 'Bubblegum', Class.new(Chewy::Index)
      }.to change{
        Searchengine::Indices.all.count
      }.by(0)
    end

    it 'provides a handler to retrieve managed indices' do
      City.searchable { }
      idx_sym = Searchengine::Indices.all.first
      expect(Searchengine::Indices.get(idx_sym)).to eq(Searchengine::Indices::CityIndex)
    end

    context "names the index" do
      before(:each) do
        #allow(City).to receive(:update_index)
      end

      it 'after the model by default' do
        expect{ 
          City.searchable { } 
        }.to change{
          City.search_index_name
        }.from(nil).to include("#{City.name}Index")
      end
  
      it 'after the specified input' do
        expect{ 
          City.searchable_as('Attrappe') { } 
        }.to change{
          City.search_index_name
        }.from(nil).to include('AttrappeIndex')
      end

      it 'after the camelized variant of the specified input' do
        expect{ 
          City.searchable_as('great_knowledge') { } 
        }.to change{
          City.search_index_name
        }.from(nil).to include('GreatKnowledge')
      end

      it 'sets up the #update_index proc'
    end

    context 'with an index' do
      before(:each) do
        Chewy.use_after_commit_callbacks = false
        allow(City).to receive(:create)
        allow(City).to receive(:after_save)
        allow(City).to receive(:after_destroy)
        City.class_eval do
          searchable_as :sandbox do |index|
            index.define_type 'City' do |type|
              type.field :email, :string
              type.field :name, :string
            end
          end
          updatable_as :sandbox, :city
        end
        City.search_index.purge!
      end

      it 'ensures the index is known to Chewy' do
        City.searchable { }
        expect(Chewy::Index.descendants).to include(City.search_index)
      end

      it 'triggers the after_save callback upon save' do
        skip
        expect(City).to receive(:update_proc).twice
        City.create(name: 'Berlin', country_id: 'de', rating: 10)
        City.create(name: 'Rotterdam', country_id: 'nl', rating: 10)
      end
    end
  end
end
