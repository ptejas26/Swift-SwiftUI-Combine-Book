import SwiftUI
import Combine

let specialChar: String = "!#$%&*"

struct ContentView: View {
    @StateObject var viewModel = SignUpFormViewModel()
    
    var body: some View {
        NavigationView {
            Form {
                //userName
                Section {
                    TextField("Username", text: $viewModel.username)
                        .autocorrectionDisabled()
                        .autocapitalization(.none)
                } footer: {
                    Text(viewModel.usernameMessage)
                        .foregroundColor(.red)
                }
                
                //userName
                Section {
                    SecureField("Password", text: $viewModel.password)
                    SecureField("Confirm Password", text: $viewModel.passwordConfirmation)
                } footer: {
                    VStack(alignment: .leading) {
                        Text(viewModel.passwordMessage)
                            .foregroundColor(.red)
                        Text("Password Requirements:")
                            .font(.caption2)
                            .padding([.top, .bottom], 5)
                        ForEach(viewModel.requirementArray, id: \.id) { item in
                            PasswordRequirementView(requirement: item)
                        }
                    }
                }
                Section {
                    Button("Sign up") {
                        print("Signing up as \(viewModel.username)")
                    }
                }
                .disabled(!viewModel.isValid)
            }
            
            .navigationTitle("Registeration Screen")
            .navigationBarTitleDisplayMode(.automatic)
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
}
