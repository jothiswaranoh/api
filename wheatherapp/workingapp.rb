require 'sinatra'
require 'httparty'
require 'json'
require 'dotenv/load' # Load environment variables from .env file (if present)

# Load your API key from an environment variable or a config file.
# Replace 'YOUR_API_KEY' with the actual API key.
API_KEY = ENV['WEATHER_API_KEY'] || 'dbcd2244dc5d433f8dc92918232207'

get '/weather/:location' do
  location = params[:location]

  begin
    response = HTTParty.get("http://api.weatherapi.com/v1/current.json?key=#{API_KEY}&q=#{location}")
    
    # Manually check the response status and raise an error if it's not successful (2xx status code)
    unless response.success?
      raise StandardError, "Received non-successful response with status code: #{response.code}"
    end

    weather_data = response.parsed_response # JSON response data
    formatted_weather_data = process_weather_data(weather_data) # Custom method to format the weather data
    content_type :json
    { location: location, weather: formatted_weather_data }.to_json
  rescue HTTParty::Error, StandardError => e
    status 500
    content_type :json
    { error: "Error fetching weather data: #{e.message}" }.to_json
  end
end

def process_weather_data(weather_data)
  # Assuming the weather API response is in the following JSON format:
  # {
  #   "current": {
  #     "temp_c": 25.0,
  #     "humidity": 62,
  #     "wind_kph": 12.0,
  #     "condition": {
  #       "text": "Partly cloudy"
  #     }
  #   }
  # }

  temperature = weather_data.dig('current', 'temp_c')
  humidity = weather_data.dig('current', 'humidity')
  wind_speed = weather_data.dig('current', 'wind_kph')
  weather_description = weather_data.dig('current', 'condition', 'text')

  {
    temperature: temperature.to_f.round(1), # Convert temperature to float and round to 1 decimal place
    humidity: humidity.to_i,
    wind_speed: wind_speed.to_f.round(1), # Convert wind speed to float and round to 1 decimal place
    description: weather_description
  }
end
