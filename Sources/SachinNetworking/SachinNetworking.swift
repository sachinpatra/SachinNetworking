
//
//  SachinNetworking.swift
//  PracticeApp
//
//  Created by H454276 on 26/12/25.
//

import Foundation
import Combine


public enum SachinNetworkError: Error {
    case requestFailed
}

  public protocol SachinNetworkProtocol {
    func fetchUsingPublisher<T: Codable>(urlString: String) -> AnyPublisher<T, Error>
    func fetchUsingDataTaskCompletion<T: Codable>(urlString: String) -> AnyPublisher<T, Error>
    func fetchUsingData<T: Codable>(urlString: String) async throws -> T
    func parse<T: Decodable>(data: Data) throws -> T
}

public struct SachinNetwork: SachinNetworkProtocol {
    public func fetchUsingData<T>(urlString: String) async throws -> T where T : Decodable, T : Encodable {
        do {
            let (data, response) = try await URLSession.shared.data(for: URLRequest(url: URL(string: urlString)!))
            guard let httpresponse = response as? HTTPURLResponse, 200...300 ~= httpresponse.statusCode  else {
                throw SachinNetworkError.requestFailed
            }
            let result: T = try parse(data: data)
            return result
        } catch {
            throw SachinNetworkError.requestFailed
        }
    }
    
    public func fetchUsingPublisher<T>(urlString: String) -> AnyPublisher<T, any Error> where T : Decodable, T : Encodable {
        URLSession.shared.dataTaskPublisher(for: URL(string: urlString)!)
            .tryMap { (data, response) -> Data in
                guard let httpresponse = response as? HTTPURLResponse, 200..<300 ~= httpresponse.statusCode else {
                    throw SachinNetworkError.requestFailed
                }
                return data
            }
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
    
    public func fetchUsingDataTaskCompletion<T>(urlString: String) -> AnyPublisher<T, any Error> where T : Decodable, T : Encodable {
        Deferred {
            Future<T, Error> { promis in
                URLSession.shared.dataTask(with: URLRequest(url: URL(string: urlString)!)) { data, response, error in
                    guard let httpresponse = response as? HTTPURLResponse, 200..<300 ~= httpresponse.statusCode else {
                        promis(.failure(SachinNetworkError.requestFailed))
                        return
                    }
                    guard let data = data  else {
                        promis(.failure(SachinNetworkError.requestFailed))
                        return
                    }
                    do {
                        let result = try JSONDecoder().decode(T.self, from: data)
                        promis(.success(result))
                    } catch let error {
                        promis(.failure(error))
                    }
                }
                .resume()
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func parse<T>(data: Data) throws -> T where T : Decodable {
        do {
            let result = try JSONDecoder().decode(T.self, from: data)
            return result
        } catch let error {
            throw error
        }
    }
}
