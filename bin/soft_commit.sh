# change value below 
# do a "soft commit" - "this will refresh the 'view' of the index in a more performant manner, but without "on-disk" guarantees"
#   http://wiki.apache.org/solr/UpdateXmlMessages#A.22commit.22_and_.22optimize.22
curl "https://sul-solr-test.stanford.edu/solr/frda/update" -H "Content-Type: application/xml" --data-binary '<commit softCommit="true"/>'
