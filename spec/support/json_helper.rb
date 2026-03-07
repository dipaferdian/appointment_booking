module JsonHelper
  def json_parse
    JSON.parse(response.body, symbolize_names: true)
  end
end
