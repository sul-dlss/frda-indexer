# encoding: UTF-8

module NormalizationHelper
  
  # turns the String representation of the date to a Date object.  
  #  Logs a warning message if it can't parse the date string.
  # @param [String] date_str a String representation of a date
  # @return [Date] a Date object
  def normalize_date date_str
    begin
      norm_date = date_str.gsub(/ +\- +/, '-')
      norm_date.gsub!(/-00$/, '-01')
      norm_date.concat('-01-01') if norm_date.match(/^\d{4}$/)
      norm_date.concat('-01') if norm_date.match(/^\d{4}\-\d{2}$/)
      Date.parse(norm_date)
    rescue
      @logger.warn("Found <date> tag with unparseable date value: '#{date_str}' in page #{doc_hash[:id]}") if @in_body || @in_back
      nil
    end
  end

  # normalize the session title (date) text by 
  #  removing trailing and leading chars
  #  changing any " , "  to ", "
  #  changing "Stance" to "Séance"
  #  changing "Seance" to "Séance"
  def normalize_session_title session_title
    remove_trailing_and_leading_characters session_title
    # outer parens
    session_title.gsub! /\A\(/, ''
    session_title.gsub!(/\)\z/, '') if !session_title.match(/\(\d\)\z/) 
    remove_trailing_and_leading_characters session_title
    session_title.gsub! /\A['-]/, ''   # more leading chars
    session_title.gsub! /[*"]\z/, ''   # more trailing chars
    remove_trailing_and_leading_characters session_title
    session_title.gsub! /\s,\s/, ', '
    session_title.gsub! /\AS[et]ance/, 'Séance'
    session_title.gsub! /\As[eé]ance/, 'Séance'
    session_title.gsub! /\s+/, ' '
    session_title
  end
  
  def normalize_speaker name
    remove_trailing_and_leading_characters(name) # first pass
    name.sub! /\Am{1,2}'?[. -]/i,'' # lop off beginning m and mm type cases (case insensitive) and other random bits of characters
    name.sub! /\s*[-]\s*/,'-' # remove spaces around hypens
    name.sub! /[d][']\s+/,"d'" # remove spaces after d'
    name.gsub! '1e','Le' # flip a 1e to Le
    remove_trailing_and_leading_characters(name) # second pass after other normalizations
    name[0]=name[0].capitalize # capitalize first letter
    name="Le Président" if president_alternates.include?(name) # this should come last so we complete all other normalization
    return name
  end
  
  def president_alternates
      [
        "Le pr ésident",
        "Le Pr ésident",
        "Le Pr ésident Sieyès",
        "Le Pr ésident de La Houssaye",
        "Le Pr ésident répond",
        "Le Pr ésldent",
        "Le President",
        "Le Preésident",
        "Le président",
        "Le Président",
        "Le Preésident",
        "Le Préesident",                
        "Le Président Sieyès",
        "Le Président de La Houssaye",
        "Le Président répond",
        "Le Présldent",
      ]
  end
  
  def remove_trailing_and_leading_characters name
    name.strip! # strip leading and trailing spaces
    name.sub! /\A('|\(|\)|>|<|«|\.|:|,)+/,'' # lop off any beginning periods, colons, commas and other special characters
    name.sub! /(\.|,|:)+\z/,'' # lop off any ending periods, colons or commas
    name.strip!
    name
  end
end
