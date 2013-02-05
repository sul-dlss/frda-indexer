# encoding: UTF-8
require 'spec_helper'

require 'time'

describe ApTeiDocument do
  before(:all) do
    @volume = 'Volume 36'
    @druid = 'aa222bb4444'
    @rsolr_client = RSolr::Client.new('http://somewhere.org')
    @logger = Logger.new(STDOUT)
    @atd = ApTeiDocument.new(@rsolr_client, @druid, @volume, @logger)
    @parser = Nokogiri::XML::SAX::Parser.new(@atd)
    @start_tei_body_div2_session = "<TEI.2><text><body>
          <div1 type=\"volume\" n=\"36\">
            <div2 type=\"session\">
              <pb n=\"\" id=\"wb029sv4796_00_0005\"/>"
    @end_div2_body_tei = "<pb n=\"\" id=\"wb029sv4796_00_0008\"/>
            </div2></div1></body></text></TEI.2>"
  end
  
  context "start_document" do
    it "should call init_doc_hash" do
      @atd.should_receive(:init_doc_hash).and_call_original
      x = "<TEI.2><teiHeader id='666'></TEI.2>"
      @parser.parse(x)
    end
  end
  
  context "init_doc_hash" do
    before(:all) do
      x = "<TEI.2><teiHeader id='666'></teiHeader></TEI.2>"
      @parser.parse(x)
    end
    it "should populate druid_ssi field" do
      @atd.doc_hash[:druid_ssi].should == @druid
    end
    it "should populate collection_ssi field" do
      @atd.doc_hash[:collection_ssi].should == ApTeiDocument::COLL_VAL
    end
    it "should populate vol_num_ssi field" do
      @atd.doc_hash[:vol_num_ssi].should == @volume.sub(/^Volume /i, '')
      @atd.doc_hash[:vol_num_ssi].should == '36'
    end
    it "should populate vol_title_ssi" do
      @atd.doc_hash[:vol_title_ssi].should == VOL_TITLES[@volume.sub(/^Volume /i, '')]
    end
    it "should get volume date fields in UTC form (1995-12-31T23:59:59Z)" do
      val = @atd.doc_hash[:vol_date_start_dti]
      val.should end_with 'Z'
      Time.xmlschema(val).xmlschema.should == val # also ensures it doesn't throw parsing error
      val = @atd.doc_hash[:vol_date_end_dti]
      val.should end_with 'Z'
      Time.xmlschema(val).xmlschema.should == val
    end
    it "should populate type_ssi field" do
      @atd.doc_hash[:type_ssi].should == ApTeiDocument::PAGE_TYPE
    end
  end # init_doc_hash
  
  context "add_doc_to_solr" do
    context "when page has no indexed content (<p>)" do
      it "pages in <front> section should not go to Solr" do
        x = "<TEI.2><text><front>
              <div type=\"frontpiece\">
                  <pb n=\"\" id=\"ns351vc7243_00_0001\"/>
                  <p>blah blah</p>
              </div>
              <div type=\"abstract\">
                  <pb n=\"ii\" id=\"ns351vc7243_00_0002\"/>
              </div></front></text></TEI.2>"
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'ns351vc7243_00_0001'))
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'ns351vc7243_00_0002'))
        @parser.parse(x)
      end
      it "blank page at beginning of <body> should not go to Solr" do
        x = "<TEI.2><text><body>
              <div1 type=\"volume\" n=\"20\">
                <pb n=\"\" id=\"pz516hw4711_00_0004\"/>
                <head>blah</head>
                <pb n=\"1\" id=\"pz516hw4711_00_0005\"/>
              </div1></body></text></TEI.2>"
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'pz516hw4711_00_0004'))
        @parser.parse(x)
      end
      it "blank pages at end of <body> should not go to Solr" do
        x = "<TEI.2><text><body>
              <div1 type=\"volume\" n=\"20\">
                <pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>
                <pb n=\"812\" id=\"tq360bc6948_00_0815\"/>
              </div1></body></text></TEI.2>"
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0814'))
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0815'))
        @parser.parse(x)
      end
      it "blank page at beginning of <back> should not go to Solr" do
        x = "<TEI.2><text><back>
              <div1 type=\"volume\" n=\"20\">
                <pb n=\"\" id=\"pz516hw4711_00_0004\"/>
                <head>blah</head>
                <pb n=\"1\" id=\"pz516hw4711_00_0005\"/>
              </div1></back></text></TEI.2>"
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'pz516hw4711_00_0004'))
        @parser.parse(x)
      end
      it "blank pages at end of <back> should not go to Solr" do
        x = "<TEI.2><text><back>
              <div1 type=\"volume\" n=\"20\">
                <pb n=\"810\" id=\"tq360bc6948_00_0813\"/>
                <p>blah blah</p>
                <pb n=\"811\" id=\"tq360bc6948_00_0814\"/>
                <pb n=\"812\" id=\"tq360bc6948_00_0815\"/>
              </div1></back></text></TEI.2>"
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0814'))
        @rsolr_client.should_not_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0815'))
        @parser.parse(x)
      end
    end # when no indexed content
    context "when page has indexed content (<p>)" do
      context "in <body>" do
        before(:all) do
          @id = "non_blank_page"
          @x = "<TEI.2><text><body>
                 <div1 type=\"volume\" n=\"20\">
                   <pb n=\"1\" id=\"#{@id}\"/>
                   <div2 type=\"session\">
                     <p>La séance est ouverte à neuf heures du matin. </p>
                     <pb n=\"2\" id=\"next_page\"/>
                  </div2></div1></body></text></TEI.2>"        
        end
        it "should write the doc to Solr" do
          @rsolr_client.should_receive(:add).with(hash_including(:druid_ssi, :collection_ssi, :vol_num_ssi, :id => @id))
          @parser.parse(@x)
        end
        it "should call init_doc_hash" do
          @atd.should_receive(:init_doc_hash).twice.and_call_original
          @rsolr_client.should_receive(:add)
          @parser.parse(@x)
        end
      end # in <body>
      context "in <back>" do
        it "pages in <back> section should write the doc to Solr" do
          x = "<TEI.2><text><back>
            <div1 type=\"volume\" n=\"14\">
              <pb n=\"813\" id=\"tq360bc6948_00_0816\"/>
              <div2 type=\"contents\">
                <head>TABLE CHRONOLOGIQUE</head>
                <p>blah blah</p>
              </div2>
            </div1>
            <div1 type=\"volume\" n=\"14\">
              <pb n=\"814\" id=\"tq360bc6948_00_0817\"/>
            </div1></back></text></TEI.2>"
          @rsolr_client.should_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0816'))
          @parser.parse(x)
        end
        it "last page in <back> section should write the doc to Solr" do
          x = "<TEI.2><text><back>
            <div1 type=\"volume\" n=\"14\">
              <pb n=\"813\" id=\"tq360bc6948_00_0816\"/>
              <div2 type=\"contents\">
                <head>TABLE CHRONOLOGIQUE</head>
                <p>blah blah</p>
              </div2>
            </div1>
            <div1 type=\"volume\" n=\"14\">
              <pb n=\"814\" id=\"tq360bc6948_00_0817\"/>
              <div2 type=\"contents\">
                <head>TABLE CHRONOLOGIQUE</head>
                <p>blah blah</p>
              </div2>
            </div1></back></text></TEI.2>"
          @rsolr_client.should_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0816'))
          @rsolr_client.should_receive(:add).with(hash_including(:id => 'tq360bc6948_00_0817'))
          @parser.parse(x)
        end        
      end # in <back>
    end # when indexed content
  end # add_doc_to_solr
  
  context "add_value_to_doc_hash" do
    context "field doesn't exist in doc_hash yet" do
      before(:all) do
        @x = @start_tei_body_div2_session + 
            "<sp>
              <speaker>M. Guadet</speaker>
              <p>blah blah</p>
            </sp>" + @end_div2_body_tei
      end
      it "should create field with Array [value] for a multivalued field - ending in m or mv" do
        @atd.should_receive(:add_value_to_doc_hash).with(:spoken_text_ftsimv, 'M. Guadet blah blah').and_call_original
        @atd.should_receive(:add_value_to_doc_hash).with(:speaker_ssim, 'M. Guadet').and_call_original
        exp_flds = {:speaker_ssim => ['M. Guadet'], :spoken_text_ftsimv => ['M. Guadet blah blah']}
        @rsolr_client.should_receive(:add).with(hash_including(exp_flds))
        @parser.parse(@x)
      end
      it "should create field with String value for a single valued field" do
        pending "need single valued field for test to be implemented"
      end
    end # field doesn't exist yet
    context "field already exists in doc_hash" do
      before(:all) do
        @x = @start_tei_body_div2_session + 
            "<sp>
              <speaker>M. Guadet</speaker>
              <p>blah blah</p>
            </sp>
            <sp>
              <speaker>M. McRae</speaker>
              <p>bleah bleah</p>
            </sp>" + @end_div2_body_tei
      end
      it "should add the value to the doc_hash Array for the field for multivalued field - ending in m or mv" do
        @atd.should_receive(:add_value_to_doc_hash).with(:spoken_text_ftsimv, 'M. Guadet blah blah').and_call_original
        @atd.should_receive(:add_value_to_doc_hash).with(:speaker_ssim, 'M. Guadet').and_call_original
        @atd.should_receive(:add_value_to_doc_hash).with(:spoken_text_ftsimv, 'M. McRae bleah bleah').and_call_original
        @atd.should_receive(:add_value_to_doc_hash).with(:speaker_ssim, 'M. McRae').and_call_original
        exp_flds = {:speaker_ssim => ['M. Guadet', 'M. McRae'], :spoken_text_ftsimv => ['M. Guadet blah blah', 'M. McRae bleah bleah']}
        @rsolr_client.should_receive(:add).with(hash_including(exp_flds))
        @parser.parse(@x)
      end
      it "should log a warning if the field isn't multivalued" do
        pending "need single valued field for test to be implemented"
      end
    end # field already exists
  end # add_value_to_doc_hash

  context "vol_page_ss" do
    it "should be present when <pb> has non-empty n attribute" do
      x = @start_tei_body_div2_session + 
            "<pb n=\"1\" id=\"something\"/>
             <p>La séance est ouverte à neuf heures du matin. </p>
             <pb n=\"2\" id=\"next_page\"/>
          </div2></div1></body></text></TEI.2>"        
      @rsolr_client.should_receive(:add).with(hash_including(:vol_page_ss => '1'))
      @parser.parse(x)
    end
    it "should not be present when <pb> has empty n attribute" do
      x = "<TEI.2><text><body>
            <div1 type=\"volume\" n=\"20\">
            <div2 type=\"session\">
                <pb n=\"\" id=\"ns351vc7243_00_0001\"/>
                <p>blah blah</p>
                <pb n=\"ii\" id=\"ns351vc7243_00_0002\"/>
            </div2></div1></body></text></TEI.2>"
      @rsolr_client.should_receive(:add).with(hash_not_including(:vol_page_ss))
      @parser.parse(x)
    end
    it "should not be present when <pb> has no n attribute" do
      x = "<TEI.2><text><body>
            <div1 type=\"volume\" n=\"20\">
            <div2 type=\"session\">
                <pb id=\"ns351vc7243_00_0001\"/>
                <p>blah blah</p>
                <pb n=\"ii\" id=\"ns351vc7243_00_0002\"/>
            </div2></div1></body></text></TEI.2>"
      @rsolr_client.should_receive(:add).with(hash_not_including(:vol_page_ss))
      @parser.parse(x)
    end
  end
  
  context "<sp> element" do
    context "speaker_ssim" do
      it "should be present if there is a non-empty <speaker> element" do
        x = @start_tei_body_div2_session +
            "<sp>
               <speaker>M. Guadet</speaker>
               <p>,secrétaire, donne lecture du procès-verbal de la séance ... </p>
            </sp>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:speaker_ssim => ['M. Guadet']))
        @parser.parse(x)
      end
      it "should have multiple values for multiple speakers" do
        x = @start_tei_body_div2_session + 
            "<sp>
              <speaker>M. Guadet</speaker>
              <p>blah blah</p>
            </sp>
            <p>hoo hah</p>
            <sp>
              <speaker>M. McRae</speaker>
              <p>bleah bleah</p>
            </sp>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_including(:speaker_ssim => ['M. Guadet', 'M. McRae']))
        @parser.parse(x)
      end
      it "should not be present if there is an empty <speaker> element" do
        x = @start_tei_body_div2_session + 
            "<sp>
               <speaker></speaker>
               <speaker/>
               <p>,secrétaire, donne lecture du procès-verbal de la séance ... </p>
             </sp>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_not_including(:speaker_ssim))
        @parser.parse(x)
      end
      it "should not be present if there is no <speaker> element" do
        x = @start_tei_body_div2_session + 
            "<p>La séance est ouverte à neuf heures du matin. </p>" + @end_div2_body_tei
        @rsolr_client.should_receive(:add).with(hash_not_including(:speaker_ssim))
        @parser.parse(x)
      end
    end # speaker_ssim

    context "spoken_text_ftsimv" do
      before(:each) do
        @x = @start_tei_body_div2_session +
            "<p>before</p>
            <sp>
               <speaker>M. Guadet</speaker>
               <p>blah blah ... </p>
               <p>bleah bleah ... </p>
            </sp>
            <p>middle</p>
            <sp>
              <p>no speaker</p>
            </sp>
            <sp>
              <speaker/>
              <p>also no speaker</p>
            </sp>
            <p>after</p>" + @end_div2_body_tei
      end
      it "should have a separate value, starting with the speaker, for each <p> inside a single <sp>" do
        @rsolr_client.should_receive(:add).with(hash_including(:spoken_text_ftsimv => ['M. Guadet blah blah ...', 'M. Guadet bleah bleah ...']))
        @parser.parse(@x)
      end
      it "should not include <p> text outside an <sp>" do
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_ftsimv => ['before']))
        @parser.parse(@x)
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_ftsimv => ['middle']))
        @parser.parse(@x)
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_ftsimv => ['after']))
        @parser.parse(@x)
      end
      it "should not include <p> text when there is no speaker " do
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_ftsimv => ['no speaker']))
        @parser.parse(@x)
        @rsolr_client.should_receive(:add).with(hash_not_including(:spoken_text_ftsimv => ['also no speaker']))
        @parser.parse(@x)
      end
    end # spoken_text_ftsimv

    it "should log a warning when it finds direct non-whitespace text content in <sp> tag" do
      x = @start_tei_body_div2_session +
          "<pb n=\"2\" id=\"ns351vc7243_00_0001\"/>
          <sp>
             <speaker>M. Guadet</speaker>
             <p>blah blah ... </p>
             mistake
          </sp>" + @end_div2_body_tei
      @logger.should_receive(:warn).with("Found <sp> tag with direct text content: 'mistake' in page ns351vc7243_00_0001")
      @rsolr_client.should_receive(:add)
      @parser.parse(x)
    end
  end # <sp> element
  

  context "<text>" do
    context "<body>" do
      context '<div2 type="session">' do
        x = "<TEI.2><text><body>
              <div1 type=\"volume\" n=\"36\">
                <pb n=\"\" id=\"wb029sv4796_00_0004\"/>
                <pb n=\"\" id=\"wb029sv4796_00_0005\"/>
                <head>ARCHIVES PARLEMENTAIRES </head>
                <head>RÈGNE DE LOUIS XVI </head>
                <div2 type=\"session\">
                 <head>ASSEMBLÉE NATIONALE LÉGISLATIVE. </head>
                 <head>Séance du<date value=\"1791-12-11\">dimanche 11 décembre 1791</date>.</head>
                 <head> PRÉSIDENCE DE M. LEMONTEY.</head>
                 <p>La séance est ouverte à neuf heures du matin. </p>
                 <sp>
                  <speaker>M. Guadet</speaker>
                  <p>,secrétaire, donne lecture du procès-verbal de la séance du samedi 10 décembre 1791, au
                   matin. </p>
                   <pb n=\"\" id=\"wb029sv4796_00_0005\"/>
                </div></body></text></TEI.2>"        
      end
    end # <body>
    context "<back>" do
      before(:all) do
           x = "<TEI.2><text><back>
           <back>
            <div1 type=\"volume\" n=\"36\">
             <pb n=\"\" id=\"wb029sv4796_00_0751\"/>

             <head>ARCHIVES PARLEMENTAIRES </head>
             <head>PREMIÈRE SÉRIE </head>
             <div2 type=\"contents\">
              <head>TABLE CHRONOLOGIQUE DU TOME XXXVI </head>
              <head>TOME TRENTE-SIXIÈME (DU 11 DÉCEMBRE 1191 AU lor JANVIER 1792). </head>
              <p>Pages. </p>
              <list>
               <head>11 DÉCEMBRE 1791. </head>

               <item>Assemblée nationale législative. — Lecture de pé- titions, lettres et adresses
                diverses............ 1</item>
             </list>
             <list>
              <head>13 DÉCEMBRE 1791</head>
              <item>Séance du matin.</item>
              <item>Assemblée nationale législative. — Motions d'or-
               dre................................................... 42 </item>
             </list>
             <list>
              <head>Séance du soir. </head>
              <item>Assemblée nationale législative. — Lecture des lettres, pétitions et adresses
               diverses.......... 75 </item>
             </list>
             </div2>
           </div1>
           <div1 type=\"volume\" n=\"36\">
            <pb n=\"\" id=\"wb029sv4796_00_0760\"/>

            <head>ARCHIVES PARLEMENTAIRES </head>
            <head>PREMIÈRE SÉRIE </head>
            <head>TABLE ALPHABÉTIQUE ET ANALYTIQUE DU TOME TRENTE-SIXIÈME. (DO 11 DÉCEMBRE 1791 AD 1<hi
              rend=\"superscript\">er</hi> JANVIER 1792) </head>
           <div2 type=\"alpha\">
            <head>W </head>
            <p><term>Wimpfen</term> (Général de). — Voir Princes français. </p>
            <p><term>Worms</term> (Ville). Le magistrat annonce à la municipalité de Strasbourg qu'il a
             requis M. de Condé de quitter la ville (30 décembre 1791, t. XXXVI, p. 666). </p>
            <p><term>Wurtemberg</term>. Réponse du duc à la notification de l'acceptation de 1 acte
             constitutionnel par Louis XVI (24 décembre 1791, t. XXXVI, p. 350). </p>
            <pb n=\"793\" id=\"wb029sv4796_00_0797\"/>
           </div2>
               <div2 type=\"alpha\">
                <head>Y </head>
                <p><term>Yonne</term> (Département de 1'). </p>
                <p>Administrateurs. — Demandent à être entendus à la barre (20 décembre 1791, t. XXXVI, p.
                 222).— Sont admis, présentent une adresse de dévouement et une demande de dégrèvement (ibid.
                 p. 278 et suiv.) ; — réponse du Président (ibid. p. 279). </p>
                <p>Volontaires. — Plaintes sur la lenteur de l'équipement (18 décembre 1791, t. XXXVI, p. 231);
                 — renvoi au comité militaire (ibid.). </p>
                <p>fin de la table alphabétique èt analytiquê du tome xxxvi.</p>
               </div2>
              </div1>
             </back>
            </text>
           </TEI.2>"
      end
    end # <back>
  end # <text>
  
  
end