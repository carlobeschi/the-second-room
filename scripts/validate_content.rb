#!/usr/bin/env ruby

require "yaml"
require "date"
require "set"

ROOT = File.expand_path("..", __dir__)
errors = []

def parse_front_matter(path)
  text = File.read(path, encoding: "UTF-8")
  unless text.start_with?("---\n")
    return [nil, ["#{path} must start with YAML front matter"]]
  end

  parts = text.split(/^---\s*$/, 3)
  unless parts.length == 3
    return [nil, ["#{path} has unclosed YAML front matter"]]
  end

  begin
    data = YAML.safe_load(
      parts[1],
      permitted_classes: [Date, Time],
      permitted_symbols: [],
      aliases: true
    )
    data ||= {}
    unless data.is_a?(Hash)
      return [nil, ["#{path} front matter must be a mapping"]]
    end
    [data, []]
  rescue Psych::Exception => error
    [nil, ["#{path} has invalid YAML: #{error.message}"]]
  end
end

config_path = File.join(ROOT, "_config.yml")
config = YAML.safe_load(File.read(config_path, encoding: "UTF-8"), aliases: true) || {}
agents = config.fetch("agents", {}).keys.map(&:to_s).to_set

scene_path = File.join(ROOT, "_data", "scenes.yml")
scenes = YAML.safe_load(File.read(scene_path, encoding: "UTF-8"), aliases: true) || {}

seasons = {}
Dir.glob(File.join(ROOT, "_seasons", "*.md")).sort.each do |path|
  data, parse_errors = parse_front_matter(path)
  errors.concat(parse_errors)
  next unless data

  number = data["number"]
  unless number.is_a?(Integer) && number.positive?
    errors << "#{path}: `number` must be a positive integer"
    next
  end
  if seasons.key?(number)
    errors << "#{path}: duplicate season #{number}"
  end
  length = data.fetch("length", 7)
  unless length.is_a?(Integer) && length.positive?
    errors << "#{path}: `length` must be a positive integer"
    length = 7
  end
  seasons[number] = length
end

episode_keys = Set.new
Dir.glob(File.join(ROOT, "_episodes", "**", "*.md")).sort.each do |path|
  data, parse_errors = parse_front_matter(path)
  errors.concat(parse_errors)
  next unless data

  %w[season day title date summary meeting journals].each do |field|
    value = data[field]
    missing = !data.key?(field) || value.nil? ||
              (value.respond_to?(:empty?) && value.empty?)
    errors << "#{path}: missing required `#{field}`" if missing
  end

  season = data["season"]
  day = data["day"]

  unless season.is_a?(Integer)
    errors << "#{path}: `season` must be an integer"
  end
  unless day.is_a?(Integer)
    errors << "#{path}: `day` must be an integer"
  end
  unless data["title"].is_a?(String) && !data["title"].strip.empty?
    errors << "#{path}: `title` must be a non-empty string"
  end
  unless data["summary"].is_a?(String) && !data["summary"].strip.empty?
    errors << "#{path}: `summary` must be a non-empty string"
  end
  begin
    date = data["date"]
    if date.is_a?(Date)
      date
    elsif date.is_a?(String)
      Date.iso8601(date)
    else
      raise ArgumentError
    end
  rescue ArgumentError
    errors << "#{path}: `date` must be an ISO 8601 date"
  end

  if season.is_a?(Integer) && day.is_a?(Integer)
    key = [season, day]
    if episode_keys.include?(key)
      errors << "#{path}: duplicate episode for season #{season}, day #{day}"
    else
      episode_keys << key
    end

    if seasons.key?(season)
      length = seasons.fetch(season)
      unless day.between?(1, length)
        errors << "#{path}: day #{day} is outside season #{season}'s length #{length}"
      end
    else
      errors << "#{path}: season #{season} has no matching `_seasons` entry"
    end
  end

  unless data["meeting"].is_a?(Array)
    errors << "#{path}: `meeting` must be a list"
  end
  Array(data["meeting"]).each_with_index do |turn, index|
    unless turn.is_a?(Hash)
      errors << "#{path}: meeting turn #{index + 1} must be a mapping"
      next
    end
    speaker = turn["by"].to_s
    if speaker != "note" && !agents.include?(speaker)
      errors << "#{path}: meeting turn #{index + 1} has unknown speaker `#{speaker}`"
    end
  end

  journals = data["journals"]
  unless journals.is_a?(Hash)
    errors << "#{path}: `journals` must be a mapping"
  end
  journals&.each do |key, text|
    agent = key.to_s
    unless agents.include?(agent)
      errors << "#{path}: journal has unknown agent `#{agent}`"
    end
    if text.nil? || (text.respond_to?(:empty?) && text.empty?)
      errors << "#{path}: journal for `#{agent}` must not be empty"
    end
  end

  if data.key?("thread")
    unless data["thread"].is_a?(Array)
      errors << "#{path}: `thread` must be a list"
    end
    Array(data["thread"]).each_with_index do |line, index|
      unless line.is_a?(Hash)
        errors << "#{path}: thread line #{index + 1} must be a mapping"
        next
      end
      speaker = line["by"].to_s
      unless agents.include?(speaker)
        errors << "#{path}: thread line #{index + 1} has unknown speaker `#{speaker}`"
      end
      unless %w[meeting journal].include?(line["from"].to_s)
        errors << "#{path}: thread line #{index + 1} has invalid `from` value"
      end
    end
  end

  if data.key?("models")
    unless data["models"].is_a?(Hash)
      errors << "#{path}: `models` must be a mapping"
    end
  end

  if data.key?("comic")
    comic = data["comic"]
    unless comic.is_a?(Hash)
      errors << "#{path}: `comic` must be a mapping"
    else
      panels = comic["panels"]
      unless panels.is_a?(Array)
        errors << "#{path}: comic `panels` must be a list"
      end
      Array(panels).each_with_index do |panel, index|
        unless panel.is_a?(Hash)
          errors << "#{path}: comic panel #{index + 1} must be a mapping"
          next
        end
        scene = panel["scene"].to_s
        unless scenes.key?(scene)
          errors << "#{path}: comic panel #{index + 1} has unknown scene `#{scene}`"
        end
        speaker = panel["by"].to_s
        unless agents.include?(speaker)
          errors << "#{path}: comic panel #{index + 1} has unknown speaker `#{speaker}`"
        end
      end

      if comic.key?("night")
        night = comic["night"]
        unless night.is_a?(Array)
          errors << "#{path}: comic `night` must be a list"
        end
        Array(night).each_with_index do |page, index|
          unless page.is_a?(Hash)
            errors << "#{path}: comic night page #{index + 1} must be a mapping"
            next
          end
          speaker = page["by"].to_s
          unless agents.include?(speaker)
            errors << "#{path}: comic night page #{index + 1} has unknown speaker `#{speaker}`"
          end
        end
      end
    end
  end
end

if errors.empty?
  puts "Content validation passed."
else
  warn "Content validation failed:"
  errors.each { |error| warn "  - #{error}" }
  exit 1
end
