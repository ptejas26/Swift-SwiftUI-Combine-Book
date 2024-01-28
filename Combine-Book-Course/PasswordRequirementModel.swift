//
//  Model.swift
//  Combine-Book-Course
//
//  Created by Tejas on 2023-12-29.
//

import Foundation

enum NetworkError: Error {
    case invalidRequsetError(String)
    case transportError(Error)
    case serverError(statusCode: Int)
    case noData
    case decodingError(Error)
}

final class PasswordRequirementModel: ObservableObject {
    @Published var id: Int = 0
    @Published var validState: Bool = false
    @Published var validMessage: String = ""
    init(id: Int, validState: Bool, validMessage: String) {
        self.id = id
        self.validState = validState
        self.validMessage = validMessage
    }
    
    init() { }
}
