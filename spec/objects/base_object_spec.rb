require 'spec_helper'

describe Fishbowl::Objects::BaseObject do
  let(:ticket) { "thisisasample" }
  let(:base_object) { Fishbowl::Objects::BaseObject.new }
  let(:connection) { FakeTCPSocket.instance }

  let(:empty_ticket_builder) do
    Nokogiri::XML::Builder.new do |xml|
      xml.FbiXml {
        xml.Ticket

        xml.FbiMsgsRq {
          xml.SampleRq
        }
      }
    end
  end

  let(:ticket_builder) do
    Nokogiri::XML::Builder.new do |xml|
      xml.FbiXml {
        xml.Ticket ticket

        xml.FbiMsgsRq {
          xml.SampleRq
        }
      }
    end
  end

  before :each do
    mock_tcp_connection
    mock_login_response
    Fishbowl::Connection.connect(host: 'localhost')
    Fishbowl::Connection.login(username: 'johndoe', password: 'secret')
  end

  after :each do
    unmock_tcp
  end

  describe "#send_request" do
    before :each do
      mock_the_response
    end

    it "should send the specified request" do
      base_object.send_request("SampleRq", "SampleRs")
      connection.last_write.should be_equivalent_to(empty_ticket_builder.to_xml)
    end

    it "should get the expected response" do
      code, message, response = base_object.send_request("SampleRq", "SampleRs")

      code.should_not be_nil
      message.should_not be_nil
      response.should be_equivalent_to(mock_response.to_xml)
    end
  end

  context "Protected Methods" do
    describe "#parse_attributes" do
      it "should parse the requested attributes from the supplied xml" do
        parse_xml = Nokogiri::XML::Builder.new do |xml|
          xml.parse {
            xml.ID "5"
            xml.DataID "15"
            xml.Name "Demo"
            xml.SKU "DEMO"
          }
        end
        parse_xml = Nokogiri::XML.parse(parse_xml.to_xml)

        class Fishbowl::Objects::BaseObject
          def self.attributes
            %w{ID DataID Name SKU}
          end
        end

        base_object.instance_variable_set("@xml", parse_xml.xpath('parse'))

        base_object.send(:parse_attributes)

        base_object.instance_variables.should include(:@db_id)
        base_object.instance_variables.should include(:@data_id)
        base_object.instance_variables.should include(:@name)
        base_object.instance_variables.should include(:@sku)

        base_object.instance_variable_get(:@db_id).should eq("5")
        base_object.instance_variable_get(:@data_id).should eq("15")
        base_object.instance_variable_get(:@name).should eq("Demo")
        base_object.instance_variable_get(:@sku).should eq("DEMO")
      end
    end
  end

  context "Private Methods" do
    describe "#build_request" do
      it "should build a request document" do
        base_object.send(:build_request, "SampleRq").to_xml.should be_equivalent_to(empty_ticket_builder.to_xml)
      end

      it "should accept an XML Builder" do
        builder = Nokogiri::XML::Builder.new { |xml| xml.request { xml.SampleRq } }
        base_object.send(:build_request, builder).to_xml.should be_equivalent_to(empty_ticket_builder.to_xml)
      end

      context "when ticket is empty" do
        it "should return an empty Nokogiri::XML::Builder" do
          base_object.send(:build_request, "SampleRq").to_xml.should be_equivalent_to(empty_ticket_builder.to_xml)
        end
      end

      context "when ticket is set" do
        before :each do
          base_object.ticket = ticket
        end

        it "should return the ticket wrapped in a Nokogiri::XML::Builder" do
          base_object.send(:build_request, "SampleRq").to_xml.should be_equivalent_to(ticket_builder.to_xml)
        end
      end
    end
  end
end
