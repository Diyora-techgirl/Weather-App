//
//  GeocodingService.swift
//  WeatherAppRemix
//
//  Created by Alex on 26/04/26.
//

import Foundation

enum GeocodingService {
    
    static func resolve(city: String) async throws -> (lat: Double, lon: Double, name: String) {
        
        var c = URLComponents(string: "https://geocoding-api.open-meteo.com/v1/search")!
        c.queryItems = [
            URLQueryItem(name: "name", value: city),
            URLQueryItem(name: "count", value: "1")
        ]
        
        let (data, _) = try await URLSession.shared.data(from: c.url!)
        let result = try JSONDecoder().decode(Response.self, from: data)
        
        guard let place = result.results?.first else {
            throw NSError(domain: "No city found", code: 0)
        }
        
        return (place.latitude, place.longitude, place.name)
    }
}

// MARK: - Response

private struct Response: Decodable {
    let results: [Place]?
}

private struct Place: Decodable {
    let name: String
    let latitude: Double
    let longitude: Double
}
