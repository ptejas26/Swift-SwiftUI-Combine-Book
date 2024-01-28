import Foundation
import Combine
import SwiftUI

enum PasswordRules: Int {
    case atleast8Chars = 0
    case atleast1UpperChar
    case atleast1LowerChar
    case atleast1Number
    case atleast1SpecialChar
}

final class SignUpFormViewModel: ObservableObject {
    
    let serviceAuthenticator = AuthenticationService()
    // Input
    @Published var username: String = ""
    @Published var password: String = ""
    @Published var passwordConfirmation: String = ""
    
    // Output
    @Published var usernameMessage: String = ""
    @Published var isValid: Bool = false
    
    @Published var passwordMessage: String = ""
    
   
    var cancellables = Set<AnyCancellable>()
    let minPasswordLength: Int = 8
    
    @State var requirementArray: [PasswordRequirementModel] = [
        PasswordRequirementModel(id: PasswordRules.atleast8Chars.rawValue, validState: false, validMessage: "MUST contain at least 8 characters (12+ recommended)"),
        PasswordRequirementModel(id: PasswordRules.atleast1UpperChar.rawValue, validState: false, validMessage: "MUST contain at least one uppercase letter"),
        PasswordRequirementModel(id: PasswordRules.atleast1LowerChar.rawValue, validState: false, validMessage: "MUST contain at least one lowercase letter"),
        PasswordRequirementModel(id: PasswordRules.atleast1Number.rawValue, validState: false, validMessage: "MUST contain at least one number"),
        PasswordRequirementModel(id: PasswordRules.atleast1SpecialChar.rawValue, validState: false, validMessage: "MUST contain at least one special character [!#$%&*]")
    ]
    
    private lazy var isUsernameLengthValidPublisher: AnyPublisher<Bool, Never> = {
        $username
            .map { $0.count >= 3 }
            .eraseToAnyPublisher()
    }()
    
    private lazy var isPasswordEmptyPublisher: AnyPublisher<Bool, Never> = {
        $password
        //            .map { $0.isEmpty }
            .map(\.isEmpty)
            .eraseToAnyPublisher()
    }()
    
    private lazy var isPasswordMatchingPublisher: AnyPublisher<Bool, Never> = {
        Publishers.CombineLatest($password, $passwordConfirmation)
            .map(==)
            .eraseToAnyPublisher()
    }()
    
    private lazy var isPasswordValidPublisher: AnyPublisher<Bool, Never> = {
        Publishers.CombineLatest(isPasswordEmptyPublisher, isPasswordMatchingPublisher)
            .map { !$0 && $1 }
            .eraseToAnyPublisher()
    }()
    
    
    private lazy var isFormValidPublisher: AnyPublisher<Bool, Never> = {
        Publishers.CombineLatest(isUsernameLengthValidPublisher, isPasswordValidPublisher)
            .map { $0 && $1 }
            .eraseToAnyPublisher()
    }()
    
    // Password Rules
    
    typealias PasswordRuleTuple = (PasswordRules, Bool)
    private lazy var passwordLengthValidPublisher: AnyPublisher<PasswordRuleTuple, Never> = {
        $password
            .map {
                let bool = $0.count >= self.minPasswordLength
                return PasswordRuleTuple(PasswordRules.atleast8Chars, bool)
            }
            .eraseToAnyPublisher()
    }()
    
    private lazy var passwordUpperCharPublisher: AnyPublisher<PasswordRuleTuple, Never> = {
        $password
            .map {
                let bool = $0.contains { chars in
                    chars.isUppercase
                }
                return PasswordRuleTuple(PasswordRules.atleast1UpperChar, bool)
            }
            .eraseToAnyPublisher()
    }()
    
    private lazy var passwordLowerCharPublisher: AnyPublisher<PasswordRuleTuple, Never> = {
        $password
            .map {
                let bool = $0.contains { chars in
                    chars.isLowercase
                }
                return PasswordRuleTuple(PasswordRules.atleast1LowerChar, bool)
            }
            .eraseToAnyPublisher()
    }()
    
    private lazy var passwordNumberPublisher: AnyPublisher<PasswordRuleTuple, Never> = {
        $password
            .map {
                let bool = $0.contains { chars in
                    chars.isNumber
                }
                return PasswordRuleTuple(PasswordRules.atleast1Number, bool)
            }
            .eraseToAnyPublisher()
    }()
    
    //    private lazy var passwordPublisher: AnyPublisher<Bool, Never> = {
    //        $password
    //            .map { $0.contains { chars in
    //                chars.isNumber
    //            } }
    //            .eraseToAnyPublisher()
    //    }()
    
    // Available username
    private lazy var isUsernameAvailable: AnyPublisher<Bool, Never> = {
        $username
            .print("Username")
            .flatMap { username -> AnyPublisher<Bool, Never> in
                self.serviceAuthenticator.checkUserNameAvailable(userName: username)
            }
            .eraseToAnyPublisher()
    }()
    
    
    
    init() {
        
        isUsernameAvailable
            .receive(on: DispatchQueue.main)
            .assign(to: &$isValid)
        
        isUsernameAvailable
            .receive(on: DispatchQueue.main)
            .map { value in
                value ? "" : "Username not available, try different one"
            }
            .assign(to: &$usernameMessage)
        
        
        isFormValidPublisher
            .assign(to: &$isValid)
        isUsernameLengthValidPublisher
            .map {
                $0 ? "" : "Username must be at least three characters!"
            }
            .assign(to: &$usernameMessage)
        
        Publishers.CombineLatest(isPasswordEmptyPublisher, isPasswordMatchingPublisher)
            .map { isPasswordEmpty, isPasswordMatching in
                
                if isPasswordEmpty {
                    return "Password must not be empty"
                }
                else if !isPasswordMatching {
                    return "Passwords do not match"
                }
                return ""
            }
            .assign(to: &$passwordMessage)
        
        Publishers.CombineLatest4(
            passwordLengthValidPublisher,
            passwordLowerCharPublisher,
            passwordUpperCharPublisher,
            passwordNumberPublisher
        )
//        .print("$$$$ ")
        .handleEvents(receiveOutput: { lenPub, lowerChar, upperChar, numberPub in
            
            self.requirementArray[lenPub.0.rawValue].validState = lenPub.1
            self.requirementArray[lowerChar.0.rawValue].validState = lowerChar.1
            self.requirementArray[upperChar.0.rawValue].validState = upperChar.1
            self.requirementArray[numberPub.0.rawValue].validState = numberPub.1
        })
        .sink (receiveValue: { _ in })
        .store(in: &cancellables)
    }
}

class AuthenticationService {
    private let url: String = "http://127.0.0.1:8080/isUserNameAvailable?userName="

    func checkUserNameAvailableOldSchool(username: String, completion: @escaping (Result<Bool, NetworkError>) -> Void) {
        guard let url = URL(string: url+"\(username)") else {
            completion(.failure(.invalidRequsetError("Invalid URL")))
            return
        }
        let task = URLSession.shared.dataTask(with: url) { data, response, error in
            
            if let error = error {
                completion(.failure(.transportError(error)))
                return
            }
            
            if let response = response as? HTTPURLResponse,
               !(200...299).contains(response.statusCode) {
                completion(.failure(.serverError(statusCode: response.statusCode)))
                return
            }
            guard let data = data else {
                completion(.failure(.noData))
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let userAvailableMessage = try decoder.decode(UserAvailableModel.self, from: data)
                completion(.success(userAvailableMessage.isAvailable ?? false))
                print(userAvailableMessage)
            } catch {
                completion(.failure(.decodingError(error)))
            }
        }
        task.resume()
    }
    
    func checkUserNameAvailableNavie(userName: String) -> AnyPublisher<Bool, Never> {
        guard let url = URL(string: url+"\(userName)") else {
            return Just(false).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map { (data: Data, response: URLResponse) in
                do {
                    let decoder = JSONDecoder()
                    let userAvailableMessage = try decoder.decode(UserAvailableModel.self, from: data)
                    return userAvailableMessage.isAvailable ?? false
                } catch {
                    return false
                }
            }
            .replaceError(with: false)
            .eraseToAnyPublisher()
    }
    
    func checkUserNameAvailable(userName: String) -> AnyPublisher<Bool, Never> {
        guard let url = URL(string: url+"\(userName)") else {
            return Just(false).eraseToAnyPublisher()
        }
        
        return URLSession.shared.dataTaskPublisher(for: url)
            .map(\.data)
            .decode(type: UserAvailableModel.self, decoder: JSONDecoder())
            .compactMap(\.isAvailable)
            .replaceError(with: false)
            .eraseToAnyPublisher()
    }
}

struct UserAvailableModel: Codable {
    
    let isAvailable : Bool?
    let userName : String?
    
    enum CodingKeys: String, CodingKey {
        case isAvailable = "isAvailable"
        case userName = "userName"
    }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        isAvailable = try values.decodeIfPresent(Bool.self, forKey: .isAvailable)
        userName = try values.decodeIfPresent(String.self, forKey: .userName)
    }
}


//self.viewModel.checkUserNameAvailableOldSchool(username: viewModel.username) { result in
//    switch result {
//    case .failure(let failure):
//        print(failure.localizedDescription)
//    case .success(let success):
//        print(success)
//    }
//    }
