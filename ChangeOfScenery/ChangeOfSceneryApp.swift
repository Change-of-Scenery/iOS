//
//  ChangeOfSceneryApp.swift
//  ChangeOfScenery
//
//  Created by Cameron Conway on 1/16/23.
//

import SwiftUI
import Firebase
import FirebaseCore
import FirebaseAuth
import GoogleMaps
import GooglePlaces

class AppDelegate: NSObject, UIApplicationDelegate {
  @EnvironmentObject var authenticationViewModel: AuthenticationViewModel

  func application(_ application: UIApplication,
                   didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
    GMSServices.provideAPIKey("AIzaSyBz7CLjfc57iSF7KPk1tQ4cEEwkQljo300")
    FirebaseApp.configure()
    GMSPlacesClient.provideAPIKey("AIzaSyCh8yeH__wOkR3Pb1Xt5A3HauZ1PdPySIg")
    UIDevice.current.beginGeneratingDeviceOrientationNotifications()
    
    return true
  }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {
  func sceneWillEnterForeground(_ scene: UIScene) {

  }
}

@main
struct ChangeOfSceneryApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    var body: some Scene {
        WindowGroup {
          NavigationView {
            ChangeOfSceneryView()
          }
          .navigationViewStyle(.stack)
       }
    }
}

//@main
//struct ChangeOfSceneryApp: App {
//    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
//    var body: some Scene {
//        WindowGroup {
//          NavigationView {
//            AuthenticatedView {
//              Image("CoSLogoTiny")
//                .resizable()
//                .frame(width: 100 , height: 100)
//                .foregroundColor(Color(.systemPink))
//                .aspectRatio(contentMode: .fit)
//                .clipShape(Circle())
//                .clipped()
//                .padding(4)
//                .overlay(Circle().stroke(Color.black, lineWidth: 2))
//              Text("Change of Scenery")
//                .font(.title)
//                .padding([.bottom], 4.0)
//            } content: {
//              ChangeOfSceneryView()
//            }
//          }
//        }
//    }
//}
