require "json"

RSpec::Matchers.define(:be_valid_json_file) do
  match do |file|
    @content = file.content
    JSON.parse(@content)
    true
  rescue JSON::ParserError => e
    @error = e
    false
  end

  failure_message do
    "Expected '#{@content}' to be valid JSON. Parser error: #{@error.inspect}"
  end
end
