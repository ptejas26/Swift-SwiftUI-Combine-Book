//
//  PasswordRequirementView.swift
//  Combine-Book-Course
//
//  Created by Tejas on 2023-12-26.
//

import SwiftUI

struct PasswordRequirementView: View {
    
    init(requirement: PasswordRequirementModel) {
        self.requirement = requirement
        image = requirement.validState ? "checkmark.circle": "x.circle"
        foregroundColor = requirement.validState ? .green : .red
    }
    
    @ObservedObject var requirement: PasswordRequirementModel
    private var image: String = "x.circle"
    private var foregroundColor: Color = .red
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: image)
                .resizable()
                .foregroundColor(foregroundColor)
                .frame(width: 20, height: 20)
                .scaledToFit()
            Text(requirement.validMessage)
        }
    }
}

struct PasswordRequirementView_Previews: PreviewProvider {
    static var previews: some View {
        PasswordRequirementView(requirement: PasswordRequirementModel(id: 1, validState: false, validMessage: "Welcome"))
    }
}
