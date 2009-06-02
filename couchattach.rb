#!/usr/bin/env ruby

require 'rubygems'
require 'couchrest'
require 'pathname'
require 'mime/types'
require 'md5'

#Hmmm...
module CouchRest
  class Database
    def put_attachment(doc, name, file, options={})
      docid=escape_docid(doc['_id'])
      uri=uri_for_attachment(doc, name)
      JSON.parse(RestClient.put(uri, file, options))
    end
  end
end


def process_pathname(doc,p)
  # puts p.inspect
  if p.directory?
    puts "Entering dir #{p.to_s}"
    p.each_entry do |subp|
      process_pathname(doc,p+subp) unless subp.fnmatch?('.*')
    end
  else
    data=File.read(p)
    md5=MD5::hexdigest(data)
    # puts "Checking #{md5} against #{@md5sums[p.to_s]} for file #{p.to_s}"
    unless md5 == @md5sums[p.to_s]
      puts "Attaching file #{p.to_s}"
      doc.put_attachment(p.to_s, File.read(p), :content_type=>MIME::Types.type_for(p.to_s).to_s)
      @md5sums[p.to_s] = md5
    end
  end
end


if ARGV.length < 3
  puts "Usage: couch_attach <database> <document id> <files> ..."
  exit
end

databasename=ARGV.shift
db=CouchRest.database!(databasename)


docid=ARGV.shift
begin
  doc=db.get(docid)
rescue
  puts "Creating document #{docid}"
  doc=CouchRest::Document.new
  doc["_id"]=docid
  db.save_doc(doc)
end

@md5sums=JSON.parse(doc["md5sums"] || "{}")

ARGV.each do |flist|
  Pathname.glob(flist).each do |filename|
    process_pathname(doc,filename)
  end
end
doc=db.get(docid)
doc["md5sums"] = @md5sums.to_json
db.save_doc(doc)