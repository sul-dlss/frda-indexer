# encoding: UTF-8

module SpeakerHelper
  
  def normalize_speaker(name)
    remove_trailing_and_leading_characters(name) # first pass
    name.sub! /\A'?m{1,2}'?[. -]/i,'' # lop off beginning m and mm type cases (case insensitive)
    name.sub! /\s*[-]\s*/,'-' # remove spaces around hypens
    name.sub! /[d][']\s+/,"d'" # remove spaces after d'
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
        "Le président",
        "Le Président",
        "Le Président Sieyès",
        "Le Président de La Houssaye",
        "Le Président répond",
        "Le Présldent",
      ]
  end
  
  def remove_trailing_and_leading_characters(name)
    name.strip! # strip leading and trailing spaces
    name.sub! /\A(«|\.|:|,)+/,'' # lop off any beginning periods, colons, commas and other special characters
    name.sub! /(\.|,|:)+\z/,'' # lop off any ending periods, colons or commas
    return name
  end
  
end
