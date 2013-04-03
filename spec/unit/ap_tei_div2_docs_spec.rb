# encoding: UTF-8
require 'spec_helper'

require 'time'

describe ApTeiDocument do
  before(:all) do
    @volume = 'Volume 36'
    @druid = 'aa222bb4444'
    @vol_constants_hash = { :vol_pdf_name_ss => 'aa222bb4444.pdf',
                            :vol_pdf_size_ls => 2218576614,
                            :vol_tei_name_ss => 'aa222bb4444.xml',
                            :vol_tei_size_is => 6885841,
                            :vol_total_pages_is => 806 }
    @page_id_hash = { 'aa222bb4444_00_0001' => 1, 
                      'aa222bb4444_00_0002' => 2, 
                      'aa222bb4444_00_0805' => 805, 
                      'aa222bb4444_00_0806' => 806 }
    @rsolr_client = RSolr::Client.new('http://somewhere.org')
    @logger = Logger.new(STDOUT)
    @atd = ApTeiDocument.new(@rsolr_client, @druid, @volume, @vol_constants_hash, @page_id_hash, @logger)
    @parser = Nokogiri::XML::SAX::Parser.new(@atd)
    @start_tei_body_div1 = "<TEI.2><text><body><div1 type=\"volume\" n=\"36\">"
    @start_tei_body_div2_session = @start_tei_body_div1 + "<div2 type=\"session\">"
    @end_div1_body_tei = "</div1></body></text></TEI.2>"
    @end_div2_body_tei = "</div2>#{@end_div1_body_tei}"
    @start_tei_back_div1 = "<TEI.2><text><back><div1 type=\"volume\" n=\"44\">"
    @end_div1_back_tei = "</div1></back></text></TEI.2>"
    @end_div2_back_tei = "</div2>#{@end_div1_back_tei}"
  end

  context "<div2> element should create doc for div2 as well as for pages" do
    context 'type="session"' do
      before(:all) do
        @x = @start_tei_body_div2_session +
            "<p>actual content</p>" + @end_div2_body_tei
      end
      it "page doc should have doc_type_ssim of 'séance' and type_ssi of 'page'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ["séance"], :type_ssi => ApTeiDocument::PAGE_TYPE))
        @parser.parse(@x)
      end
      it "div2 doc should have doc_type_ssim of 'séance' and type_ssi of 'séance'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ["séance"], :type_ssi => "séance"))
        @parser.parse(@x)
      end
    end
    
    context 'type="alpha"' do
      before(:all) do
        @x = "#{@start_tei_back_div1}<div2 type=\"alpha\">
                <pb n=\"5\" id=\"ns351vc7243_00_0001\"/>
                <p>blah blah</p>" + @end_div2_back_tei
      end
      it "page doc should have a doc_type_ssim of 'liste' and type_ssi of 'page'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ['liste'], :type_ssi => ApTeiDocument::PAGE_TYPE))
        @parser.parse(@x)
      end
      it "div2 doc should have doc_type_ssim of 'liste' and type_ssi of 'liste'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ["liste"], :type_ssi => "liste"))
        @parser.parse(@x)
      end
    end
    context 'type="contents"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"contents\">
                <pb n=\"5\" id=\"ns351vc7243_00_0008\"/>
                <p>blah blah</p>
                <pb n=\"6\" id=\"ns351vc7243_00_0009\"/>" + @end_div2_body_tei
      end
      it "page doc should have a doc_type_ssim of 'table des matières' and type_ssi of 'page'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ['table des matières'], :type_ssi => ApTeiDocument::PAGE_TYPE))
        @parser.parse(@x)
      end
      it "div2 doc should have doc_type_ssim of 'table des matières' and type_ssi of 'table des matières'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ["table des matières"], :type_ssi => "table des matières"))
        @parser.parse(@x)
      end
    end
    context 'type="other"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"other\">
                <pb n=\"5\" id=\"ns351vc7243_00_0001\"/>
                <p>blah blah</p>" + @end_div2_body_tei
      end
      it "page doc should have a doc_type_ssim of 'errata, rapport, cahier, etc.' and type_ssi of 'page'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ['errata, rapport, cahier, etc.'], :type_ssi => ApTeiDocument::PAGE_TYPE))
        @parser.parse(@x)
      end
      it "div2 doc should have doc_type_ssim of 'errata, rapport, cahier, etc.' and type_ssi of 'errata, rapport, cahier, etc.'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ["errata, rapport, cahier, etc."], :type_ssi => "errata, rapport, cahier, etc."))
        @parser.parse(@x)
      end
    end
    context 'type="table_alpha"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"table_alpha\">
                <pb n=\"5\" id=\"ns351vc7243_00_0001\"/>
                <p>blah blah</p>" + @end_div2_body_tei
      end
      it "page doc should have a doc_type_ssim of 'liste' and type_ssi of 'page'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ['liste'], :type_ssi => ApTeiDocument::PAGE_TYPE))
        @parser.parse(@x)
      end
      it "div2 doc should have doc_type_ssim of 'liste' and type_ssi of 'liste'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ["liste"], :type_ssi => "liste"))
        @parser.parse(@x)
      end
    end
    context 'type="introduction"' do
      before(:all) do
        @x = @start_tei_body_div1 + "<div2 type=\"introduction\">
                <pb n=\"5\" id=\"ns351vc7243_00_0001\"/>
                <p>blah blah</p>" + @end_div2_body_tei
      end
      it "page doc should have a doc_type_ssim of 'introduction' and type_ssi of 'page'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ['introduction'], :type_ssi => ApTeiDocument::PAGE_TYPE))
        @parser.parse(@x)
      end
      it "div2 doc should have doc_type_ssim of 'introduction' and type_ssi of 'introduction'" do
        @rsolr_client.should_receive(:add).with(hash_including(:doc_type_ssim => ["introduction"], :type_ssi => "introduction"))
        @parser.parse(@x)
      end
    end
  end # <div2> element
  
end