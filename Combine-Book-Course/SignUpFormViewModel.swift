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

enum UserNameValid: Equatable {
    case valid
    case inValid(UserNameInvalidReason)
}

enum UserNameInvalidReason {
    case tooShort
    case notAvailable
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
        Publishers.CombineLatest(isUsernameValidPublisher, isPasswordValidPublisher)
            .map { ($0 == .valid) && $1 }
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
    
    private lazy var passwordSpecialCharPublisher: AnyPublisher<PasswordRuleTuple, Never> = {
        $password
            .map {
                let bool = $0.contains { chars in
                    specialChar.contains(chars)
                }
                return PasswordRuleTuple(PasswordRules.atleast1SpecialChar, bool)
            }
            .eraseToAnyPublisher()
    }()
    
    // Available username
    private lazy var isUsernameAvailablePublisher: AnyPublisher<Bool, Never> = {
        $username
            .debounce(for: 0.4, scheduler: DispatchQueue.main)
            .removeDuplicates()
            .flatMap { username -> AnyPublisher<Bool, Never> in
                if username.count >= 3 {
                    return self.serviceAuthenticator.checkUserNameAvailable(userName: username)
                }
                return Just(false)
                    .eraseToAnyPublisher()
            }
            .receive(on: DispatchQueue.main)
            .share()
            .eraseToAnyPublisher()
    }()
    
    
    init() {
        
        Publishers.CombineLatest(isUsernameLengthValidPublisher,    isUsernameAvailablePublisher)
            .map { (validLength, userNameAvailable) in
                
                var msgString = "Great!! username avaiable"
                if !validLength {
                    msgString = "Username must be at least three characters!"
                } else if !userNameAvailable {
                    msgString = "Username not available, try different one"
                }
                return msgString
            }.assign(to: &$usernameMessage)
        
        isUsernameAvailablePublisher
            .assign(to: &$isValid)
            
        isFormValidPublisher
            .assign(to: &$isValid)
        
        
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
        
        let publisher = Publishers.CombineLatest(passwordNumberPublisher,passwordSpecialCharPublisher)
            .eraseToAnyPublisher()
        
        Publishers.CombineLatest4(
            passwordLengthValidPublisher,
            passwordLowerCharPublisher,
            passwordUpperCharPublisher,
            publisher
        )
        .handleEvents(receiveOutput: { lenPub, lowerChar, upperChar, pubisher in
            
            self.requirementArray[lenPub.0.rawValue].validState = lenPub.1
            self.requirementArray[lowerChar.0.rawValue].validState = lowerChar.1
            self.requirementArray[upperChar.0.rawValue].validState = upperChar.1
            
            publisher.handleEvents(receiveOutput: { numberPublisher, specialCharPublisher in
                
                self.requirementArray[numberPublisher.0.rawValue].validState = numberPublisher.1
                self.requirementArray[specialCharPublisher.0.rawValue].validState = specialCharPublisher.1
            })
            .sink (receiveValue: { _ in })
            .store(in: &self.cancellables)
        })
        .sink (receiveValue: { _ in })
        .store(in: &cancellables)
    }
    
    private lazy var isUsernameValidPublisher: AnyPublisher<UserNameValid, Never> = {

        return Publishers.CombineLatest(isUsernameLengthValidPublisher, isUsernameAvailablePublisher)
            .map { longEnough, available in
                if !longEnough {
                    return UserNameValid.inValid(.tooShort)
                }
                
                if !available {
                    return UserNameValid.inValid(.notAvailable)
                }
                return .valid
            }
            .share()
            .eraseToAnyPublisher()
    }()
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
