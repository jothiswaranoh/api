require 'sinatra'
require 'httparty'
require 'json'
require 'dotenv/load' # Load environment variables from .env file (if present)
require 'rubyXL'
require 'axlsx'
require 'prawn'

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

# Handle the /weather route for POST requests
post '/weather' do
  # Sample data containing location information
  sample_data = [
    { name: "jothis", place: "trichy", location: "Trichy, India" },
    { name: "arun", place: "coimbatore", location: "Coimbatore, India" },
    { name: "vasth", place: "chennai", location: "Chennai, India" }
  ]

  # Fetch weather data for each location and save it in an array
  weather_data_array = []
  sample_data.each do |loc|
    location = loc[:location]

    response = HTTParty.get("http://api.weatherapi.com/v1/current.json?key=#{API_KEY}&q=#{location}")

    # Manually check the response status and raise an error if it's not successful (2xx status code)
    unless response.success?
      raise StandardError, "Received non-successful response with status code: #{response.code}"
    end

    weather_data = response.parsed_response # JSON response data
    formatted_weather_data = process_weather_data(weather_data) # Custom method to format the weather data

    # Save the location name, place, and weather data in an array
    weather_data_array << { name: loc[:name], place: loc[:place], weather: formatted_weather_data }
  end

  # Export the weather data array to Excel and PDF
  export_to_excel_and_pdf(weather_data_array)

  status 200
  content_type :json
  { message: 'Weather data fetched and exported successfully to Excel and PDF.' }.to_json
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

def export_to_excel_and_pdf(weather_data_array)
  # Export weather data to Excel using axlsx gem
  Axlsx::Package.new do |p|
    p.workbook.add_worksheet(name: 'Weather Data') do |sheet|
      # Add header row
      sheet.add_row(['Name', 'Place', 'Temperature (°C)', 'Humidity', 'Wind Speed (kph)', 'Description'])

      # Add weather data for each location
      weather_data_array.each do |data|
        sheet.add_row([data[:name], data[:place], data[:weather][:temperature], data[:weather][:humidity], data[:weather][:wind_speed], data[:weather][:description]])
      end
    end

    # Save the Excel file
    p.serialize('weather_data.xlsx')
  end

  # Export weather data to PDF using prawn gem
  Prawn::Document.generate('weather_data.pdf') do
    text 'Weather Data', size: 24, style: :bold, align: :center

    move_down 20

    # Add weather data for each location
    weather_data_array.each do |data|
      text "Name: #{data[:name]}"
      text "Place: #{data[:place]}"
      text "Temperature (°C): #{data[:weather][:temperature]}"
      text "Humidity: #{data[:weather][:humidity]}"
      text "Wind Speed (kph): #{data[:weather][:wind_speed]}"
      text "Description: #{data[:weather][:description]}"

      move_down 10
    end
  end
end
