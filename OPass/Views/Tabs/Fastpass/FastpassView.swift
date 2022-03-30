//
//  FastpassView.swift
//  OPass
//
//  Created by 張智堯 on 2022/3/25.
//

import SwiftUI

struct FastpassView: View {
    
    @ObservedObject var eventAPI: EventAPIViewModel
    @State var isShowingLoading = false
    
    var body: some View {
        VStack {
            if eventAPI.isLogin == true {
                ScenarioView(eventAPI: eventAPI)
            } else {
                RedeemTokenView(eventAPI: eventAPI)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack {
                    Text("Fast Pass").font(.headline)
                    Text(eventAPI.display_name.en).font(.caption).foregroundColor(.gray)
                }
            }
        }
        .onAppear(perform: {
            if eventAPI.accessToken != nil {
                Task {
                    await eventAPI.loadScenarioStatus()
                }
            }
        })
    }
}

#if DEBUG
struct FastpassView_Previews: PreviewProvider {
    static var previews: some View {
        FastpassView(eventAPI: OPassAPIViewModel.mock().eventList[5])
    }
}
#endif