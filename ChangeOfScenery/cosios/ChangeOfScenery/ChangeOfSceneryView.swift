//
//  ContentView.swift
//  ChangeOfScenery
//
//  Created by Cameron Conway on 1/16/23.
//

import SwiftUI
import MapKit
import Combine
import Foundation
import CoreLocationUI
import FirebaseAuth
import FirebaseAnalyticsSwift
import FirebaseCore
import FirebaseFirestore
import GoogleMaps
import GooglePlaces
import CDYelpFusionKit
import Alamofire

struct ChangeOfSceneryView: View {
  @ObservedObject var dataSource = DataSource()
  @State private var showingAlert = false
 
  var body: some View {
    let cosMap = CoSMap(dataSource: dataSource)
    ZStack {
      cosMap
        .edgesIgnoringSafeArea(.all)
        .analyticsScreen(name: "ChangeOfSceneryView")
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
            Menu {
              Button("Washington DC") {
                dataSource.city = "WashingtonDC"
              }
              Button("Boston MA") {
                dataSource.city = "Boston"
              }
              Button("Charleston SC") {
                dataSource.city = "Charleston"
              }
              Button("Contact Us") {
                showingAlert = true
              }
            } label: {
              Label(
                title: { },
                icon: {Image(systemName: "ellipsis.circle.fill").foregroundColor(.black)}
              )
            }
          }
          if dataSource.level == "place" && dataSource.ready == true {
            ToolbarItem(placement: .cancellationAction) {
              Button {
                dataSource.level = "area"
              } label: {
                Image(systemName: "chevron.backward.circle.fill").foregroundColor(.black)
              }
            }
          }
        }

      Text(verbatim: dataSource.message)
        .padding(.all, 10)
        .foregroundColor(.init(CGColor(gray: 0.25, alpha: 1.0)))
        .font(.system(size: 15.0).bold())
        .background(.white)
        .cornerRadius(10)
        .opacity(dataSource.message.count == 0 ? 0 : 1)
    }
    .alert(isPresented: $showingAlert) {
        return Alert(title: Text("Contact Info"), message: Text("info@changeofscenery.info"), dismissButton: .default(Text("OK")))
    }
  }
}

class DataSource: ObservableObject {
  @Published var ready = true
  @Published var level = "area"
  @Published var city = "WashingtonDC"
  @Published var center = CLLocationCoordinate2D(latitude: 38.96404, longitude: -77.08884)
  @Published var span = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
  @Published var message = "Loading..."
}

//struct ChangeOfSceneryView_Previews: PreviewProvider {
//    static var previews: some View {
//      ChangeOfSceneryView()
//    }
//}

struct CoSMap: UIViewRepresentable {
  var dataSource: DataSource
  public static var mapView = MKMapView()

  func makeUIView(context: Context) -> MKMapView {
    let configuration = MKStandardMapConfiguration()
    configuration.pointOfInterestFilter = MKPointOfInterestFilter(including: [.park, .parking])
    CoSMap.mapView = MKMapView()
    CoSMap.mapView.delegate = context.coordinator
    CoSMap.mapView.region = MKCoordinateRegion(center: dataSource.center, span: dataSource.span)
    CoSMap.mapView.preferredConfiguration = configuration
    CoSMap.mapView.showsUserLocation = true
    return CoSMap.mapView
  }

  func updateUIView(_ view: MKMapView, context: Context) {
    if context.coordinator.currentCity != dataSource.city {
      context.coordinator.currentCity = dataSource.city
      context.coordinator.currentImageFolder = dataSource.city.replacingOccurrences(of: " ", with: "%20")
      let db = Firestore.firestore()
      let name = context.coordinator.currentCity.lowercased()
      db.collection("Cities").whereField("Name", in: [name]).getDocuments { queryCities, err in
        let city = queryCities!.documents.first
        let center:GeoPoint = city!.get("Center") as! GeoPoint
        self.dataSource.center = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)
        let zoom = city!.get("Zoom") as? Float ?? 14
        switch zoom {
        case 16:
          self.dataSource.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        default:
          self.dataSource.span = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
        }
        view.setRegion(MKCoordinateRegion(center: dataSource.center, span: dataSource.span), animated: true)
        context.coordinator.getAreas(view)
      }
    } else if dataSource.level == "area" && context.coordinator.currentLevel == "place" {
      context.coordinator.currentLevel = dataSource.level
      if view.region.span.latitudeDelta < dataSource.span.latitudeDelta {
        context.coordinator.removePlacePoints(view)
        view.setRegion(MKCoordinateRegion(center: dataSource.center, span: dataSource.span), animated: true)
      }
    }
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }

  class Coordinator: NSObject, MKMapViewDelegate {
    var parent: CoSMap
    var areaName = ""
    var areaZoom: Float = 20
    var placePoints: [Point] = []
    var placeCounter = 0
    var areaPoints: [Point] = []
    var pointImages: Dictionary<String, UIImage>
    var loadedAreas = false
    let locationManager = LocationManager()
    var timer = Timer()
    var lastTime = Date()
    var lastSpan = MKCoordinateSpan()
    var gotAreas = false
    var notGoingToArea = true
    let bannerPoints = ["Bethesda Row", "Bradley Shopping Center", "Friendship Heights", "Westbard Square", "Sumner Place", "Friendship Heights DC", "City Center", "Penn Quarter", "Chinatown"]
    var currentImageFolder = "Washington%20DC"
    var authenticated = false
    var currentLevel = "area"
    var currentCity = "WashingtonDC"
    
    public static var yelpAPIClient = CDYelpAPIClient(apiKey: "iQQOaKrSKp4-7jORkK8tYfQiUxHIn78-HefSRafOvFG-AvvoNRwjQhj4_Kb0mqX3IOM__qcUBApaUcTY-YZQLHWY2THQxsiZjKV5zoSD0tcZP5GCCCfFJclGTX33Y3Yx")
    
    init(_ parent: CoSMap) {
      self.parent = parent
      self.pointImages = Dictionary<String, UIImage>()
    }
    
    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
      if gotAreas == false {
        gotAreas = true
        if authenticated == false {
          Task {
            do {
              try await Auth.auth().signIn(withEmail: "cconway@cambuilt.com", password: "FerGle@123")
              authenticated = true
              getAreas(mapView)
//              loadGoogleReviews(areaName: "Bethesda Row", updateType: "PlaceData")
//              loadGoogleReviews(areaName: "Bethesda Row", updateType: "ReviewsData")
//              loadYelpReviews(areaName: "Bethesda Row", updateType: "PlaceData")
//              loadYelpReviews(areaName: "Bethesda Row", updateType: "ReviewsData")
              return true
            }
            catch  {
              print(error)
              return false
            }
          }
        } else {
          getAreas(mapView)
        }
      }
    }
       
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
      if timer.isValid == false && parent.dataSource.level == "place" {
        let lastLatDelta = (self.lastSpan.latitudeDelta * 10000000).rounded()
        let lastLngDelta = (self.lastSpan.longitudeDelta * 10000000).rounded()
        let nowLatDelta = (mapView.region.span.latitudeDelta * 10000000).rounded()
        let nowLngDelta = (mapView.region.span.longitudeDelta * 10000000).rounded()
        let notZooming = (lastLatDelta == nowLatDelta && lastLngDelta == nowLngDelta) && self.notGoingToArea == true
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
          if Date().timeIntervalSince(self.lastTime) > 0.1 {
            if notZooming == false && mapView.region.span.longitudeDelta < 0.03 {  // (mapView.annotations.count < 20)
              self.notGoingToArea = true
              self.updatePlaces(mapView)
            }
            timer.invalidate()
          }
        }
      } else {
        self.lastTime = Date()
        self.lastSpan = mapView.region.span
      }
    }
    
    func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
      if let titleTry = annotation.title {
        if let title = titleTry {
          let annotationView = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: title)
          annotationView.glyphImage = UIImage(systemName: "building.2.fill")
          return annotationView
        } else {
          let placePoint = placePoints.first { point in
            point.annotation.coordinate.longitude == annotation.coordinate.longitude && point.annotation.coordinate.latitude == annotation.coordinate.latitude
          }!
           
          let imageName = Coordinator.sanitizeImageName(name: currentCity == "Charleston" ? placePoint.address.replacingOccurrences(of: " ", with: "") : placePoint.name)
          let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: imageName)
          var portraitMultiple:Double
          var landscapeMultiple:Double
          let screenSizeMultiple = UIScreen.main.bounds.width >= 1024 || UIScreen.main.bounds.width >= 1024 ? 0.65 : 0
          let area = areaName.replacingOccurrences(of: " ", with: "")
          
          switch areaZoom {
          case 21:
            portraitMultiple = 200 - Double(200 * screenSizeMultiple)
            landscapeMultiple = 50 - Double(50 * screenSizeMultiple)
          case 17.5:
            portraitMultiple = 19000 - Double(19000 * screenSizeMultiple)
            landscapeMultiple = 75 - Double(75 * screenSizeMultiple)
          case 18:
            portraitMultiple = 8000 - Double(8000 * screenSizeMultiple)
            landscapeMultiple = 200 - Double(200 * screenSizeMultiple)
          case 18.5:
            portraitMultiple = 12000 - Double(12000 * screenSizeMultiple)
            landscapeMultiple = 50 - Double(50 * screenSizeMultiple)
          case 18.75:
            portraitMultiple = 600 - Double(600 * screenSizeMultiple)
            landscapeMultiple = 100 - Double(100 * screenSizeMultiple)
          case 19:
            portraitMultiple = 16000 - Double(16000 * screenSizeMultiple)
            landscapeMultiple = 300 - Double(300 * screenSizeMultiple)
          case 19.5:
            portraitMultiple = 15000 - Double(15000 * screenSizeMultiple)
            landscapeMultiple = 300 - Double(300 * screenSizeMultiple)
          default:
            portraitMultiple = 19000 - Double(19000 * screenSizeMultiple)
            landscapeMultiple = 900 - Double(900 * screenSizeMultiple)
          }
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          
          let multiple:Double = UIDevice.current.orientation.isLandscape ? landscapeMultiple : portraitMultiple
          
          if annotationView == nil || placePoint.name == "Chinatown" {
            let divider = mapView.region.span.longitudeDelta * multiple
            let placeMarkerAnnotationView = PlaceMarkerAnnotationView(annotation: annotation, reuseIdentifier: imageName)
            placeMarkerAnnotationView.glyphImage = nil
            placeMarkerAnnotationView.glyphTintColor = UIColor.clear
            placeMarkerAnnotationView.markerTintColor = UIColor.clear
            placeMarkerAnnotationView.canShowCallout = true
            placeMarkerAnnotationView.detailCalloutAccessoryView = Callout(placePoint: placePoint, currentImageFolder: currentImageFolder)
            placeMarkerAnnotationView.googlePlaceId = placePoint.googlePlaceId
            if !self.bannerPoints.contains(where: { banner in
              banner == placePoint.name
            }) {
              if let image = UIImage(named: "\(area)/\(imageName)") {
                let newWidth = image.size.width / divider
                let newHeight = image.size.height / divider
                let newSize = CGSize(width: newWidth, height: newHeight)
                placeMarkerAnnotationView.image = image.imageScaledToSize(size: newSize, isOpaque: false)
                self.pointImages[imageName] = image
              }
            } else {
              placeMarkerAnnotationView.image = UIImage(named: "\(area)/\(imageName)")!
            }
            self.placeCounter += 1
            if self.placeCounter >= self.placePoints.count {
              self.parent.dataSource.message = ""
              self.parent.dataSource.ready = true
            }
            // }
            return placeMarkerAnnotationView
          } else {
            let divider = mapView.region.span.longitudeDelta * multiple
            if let placeAnnotationView = annotationView as? PlaceMarkerAnnotationView {
              placeAnnotationView.annotation = annotation
              placeAnnotationView.glyphImage = nil
              placeAnnotationView.glyphTintColor = UIColor.clear
              placeAnnotationView.markerTintColor = UIColor.clear
              if !self.bannerPoints.contains(where: { banner in
                banner == placePoint.name
              }) {
                if let image = self.pointImages[imageName] {
                  let newWidth = image.size.width / divider
                  let newHeight = image.size.height / divider
                  placeAnnotationView.image = image.imageScaledToSize(size: CGSize(width: newWidth, height: newHeight), isOpaque: false)
                }
              } else {
                placeAnnotationView.image = UIImage(named: "\(area)/\(imageName)")!
              }
              placeCounter += 1
              if placeCounter >= placePoints.count {
                parent.dataSource.message = ""
                parent.dataSource.ready = true
              }
              return placeAnnotationView
            } else {
              return nil
            }
          }
        }
      } else {
        return nil
      }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView)
    {
      if view.annotation!.title! != nil {
        self.parent.dataSource.ready = false
        let displayName = view.annotation!.title!!
        let db = Firestore.firestore()
        db.collection("\(parent.dataSource.city)Area").whereField("DisplayName", in: [displayName]).getDocuments { queryArea, err in
          for document in queryArea!.documents {
            self.areaName = document.get("DisplayName") as! String
            let areaCenter = document.get("AreaCenter") as! GeoPoint
            self.areaZoom = document.get("Zoom") as? Float ?? 20
            var delta = 0.002
            switch self.areaZoom {
            case 17:
              delta = 0.015
            case 17.5:
              delta = 0.008
            case 18:
              delta = 0.01
            case 18.5:
              delta = 0.005
            case 19:
              delta = 0.0015
            case 19.5:
              delta = 0.0015
            default:
              delta = 0.002
            }
            self.notGoingToArea = false
            self.removePlacePoints(mapView)
            self.getPlaces(mapView, areaTitle: displayName)
            mapView.setRegion(MKCoordinateRegion(center: CLLocationCoordinate2D(latitude: areaCenter.latitude, longitude: areaCenter.longitude), span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)), animated: true)
          }
          self.parent.dataSource.level = "place"
          self.currentLevel = "place"
        }
      } else {
        view.detailCalloutAccessoryView!.superview?.superview?.backgroundColor = .white
        view.detailCalloutAccessoryView!.superview?.superview?.layer.borderWidth = 1.0
        view.detailCalloutAccessoryView!.superview?.superview?.layer.borderColor = .init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.2)
        if let placeView = view as? PlaceMarkerAnnotationView {
          Coordinator.yelpAPIClient.cancelAllPendingAPIRequests()
//          loadCallout(googlePlaceId: placeView.googlePlaceId, requestId:nil)
          
          if placeView.placeName == "Village of Friendship Heights" {
            placeView.placeName = "Friendship Heights Village Community Center"
          } else if placeView.placeName == "Sephora Wisconsin Place" {
            placeView.placeName = "Sephora"
          }

          if let callout = view.detailCalloutAccessoryView as? Callout, let annotation = view.annotation {
            let placePoint = placePoints.first { point in
              point.annotation.coordinate.longitude == annotation.coordinate.longitude && point.annotation.coordinate.latitude == annotation.coordinate.latitude
            }!
            setupYelpRatings(callout: callout, annotation: annotation, placePoint: placePoint)
            setupGoogleRatings(callout: callout, placePoint: placePoint)
            if callout.reviewsBar.subviews.count < 2 {
              callout.reviewsBar.removeFromSuperview()
              callout.notesTextView.topAnchor.constraint(equalTo: callout.imageView.bottomAnchor, constant: 10).isActive = true
            }
          }
        }
      }
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
      UIImageView.setMapMovementEnabled(enabled: true)
    }
    
    func loadGoogleReviews(areaName:String, updateType:String) {
      let db = Firestore.firestore()
      UIImageView.reviewCount = 0
      
//      db.collection("GoogleReview").getDocuments { queryReviews, err in
//        let reviews = queryReviews!.documents
//        for review in reviews {
//          let documentId = review.documentID
//          db.collection("GoogleReview").document(documentId).delete()
//        }
//      }
      
      // parent.dataSource.city
      
      db.collection("WashingtonDC").whereField("Area", in: [areaName]).getDocuments { queryPlaces, err in
        let places = queryPlaces!.documents
        UIImageView.reviewTotal = places.count
        for place in places {
          let googlePlaceId = place.get("GooglePlaceId") as! String
          if place.get("YelpPlaceId") == nil {
            self.updateGooglePlace(googlePlaceId: googlePlaceId, requestId: nil, documentId: place.documentID, updateType: updateType)
          }
        }
      }
    }
    
    func loadYelpReviews(areaName:String, updateType:String) {
      let db = Firestore.firestore()
      UIImageView.reviewCount = 0
      
//      db.collection("YelpReview").getDocuments { queryReviews, err in
//        let reviews = queryReviews!.documents
//        for review in reviews {
//          let documentId = review.documentID
//          db.collection("YelpReview").document(documentId).delete()
//        }
//      }
      
      db.collection(parent.dataSource.city).whereField("Area", in: [areaName]).getDocuments { queryPlaces, err in
        let places = queryPlaces!.documents
        UIImageView.reviewTotal = places.count
        for place in places {
          if place.get("Name") as! String == "Salsa with Silvia" || place.get("Name") as! String == "The Barking Dog" || place.get("Name") as! String == "Tatte Cafe" {
            if updateType == "PlaceData" {
              let query = (place.get("Name") as! String).replacingOccurrences(of: " City Center", with: "").replacingOccurrences(of: " CityCenter", with: "").replacingOccurrences(of: "&", with: "").replacingOccurrences(of: "é", with: "e").replacingOccurrences(of: "è", with: "e").replacingOccurrences(of: " ", with: "%2B").replacingOccurrences(of: "ã", with: "a")
              self.updateYelpPlace(query: query, requestId: nil, documentId: place.documentID, updateType: updateType)
            } else {
              if let query = place.get("YelpPlaceId") as? String {
                self.updateYelpPlace(query: query, requestId: nil, documentId: place.documentID, updateType: updateType)
              }
            }
          }
        }
      }
    }
    
    func updateYelpPlace(query:String?, requestId:String?, documentId:String, updateType:String) {
      var url = URL(string:"about:blank")!
      let headers: HTTPHeaders = ["Content-type": "application/x-www-form-urlencoded", "X-API-KEY": "YXV0aDB8NjQxMDc3ZjRjYjNiYWE4Yjg5M2Y0MmUwfDVkOGZmYzIzNmI"]
      
      if let requestId = requestId {
        url = URL(string: "https://api.app.outscraper.com/requests/\(requestId)")!
      } else if let query = query {
        let fieldList = updateType == "ReviewsData" ? "status,id,reviews_data" : "status,id,biz_id,price_range,rating,reviews,name"   // reservation_links
        if updateType == "PlaceData" {
          let urlString = "https://api.app.outscraper.com/yelp-search?query=https%3A%2F%2Fwww.yelp.com%2Fsearch%3Ffind_desc%3D\(query)%26find_loc%3DBethesda%2BMD&fields=\(fieldList)"
          url = URL(string: urlString)!
        } else {
          let urlString = "https://api.app.outscraper.com/yelp/reviews?query=\(query)&limit=5&async=false&sort=date_desc"
          url = URL(string: urlString)!
        }
      }
      
      do {
        let urlRequest = try URLRequest(url: url, method: .get, headers: headers)
        getData(from: urlRequest) { data, response, error in
          guard let data = data, error == nil else {
            UIImageView.reviewCount += 1
            print("Processed Yelp \(UIImageView.reviewCount) of \(UIImageView.reviewTotal)")
            return
          }
          do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
              if let status = json["status"] as? String {
                if status == "Pending" {
                  if let id = json["id"] as? String {
                    self.updateYelpPlace(query: query, requestId: id, documentId: documentId, updateType: updateType)
                  }
                } else if status == "Success" {
                  let db = Firestore.firestore()
                  self.timer.invalidate()
                  
                  if let jsonData = json["data"] as? [Any] {
                    if updateType == "PlaceData" {
                      let placeJson = jsonData.first
                      if let placeJsonArray = placeJson as? [Any], placeJsonArray.count > 0 {
                        if let placeData = placeJsonArray[0] as? [String:Any] {
                          var updatePlaceId = ""
                          if let placeId = placeData["biz_id"] as? String {
                            updatePlaceId = placeId
                          }
                          var updateRating = 0.0
                          if let rating = placeData["rating"] as? Double {
                            updateRating = rating
                          }
                          var updateReviews = 0
                          if let reviews = placeData["reviews"] as? Int {
                            updateReviews = reviews
                          }
                          var updatePrice = ""
                          if let price = placeData["price_range"] as? String {
                            updatePrice = price
                          }
                          db.collection("WashingtonDC").document(documentId).updateData(["YelpPlaceId": updatePlaceId, "YelpRating":updateRating, "YelpReviews":updateReviews, "Price":updatePrice])
                        }
                      } else {
                        print("no data for \(query!), \(placeJson!)")
                      }
                    } else {
                      let reviewJson = jsonData.first
                      if let reviewJsonArray = reviewJson as? [[String : Any]], reviewJsonArray.count > 0 {
                        for review in reviewJsonArray {
                          var reviewText = review["review_text"] as! String
                          if let ownerReplies = review["owner_replies"] as? [String], ownerReplies.count > 0 {
                            reviewText += "<br/><br/><strong>Owner Response(s)</strong><br/><br/>"
                            for reply in ownerReplies {
                              reviewText += reply + "<br/><br/>"
                            }
                          }
                          let authorName = review["author_title"] as! String
                          let reviewRating = review["review_rating"] as! Int
                          let reviewDate = review["date"] as! String
                          db.collection("YelpReview").addDocument(data: [
                            "YelpPlaceId" : query!,
                            "AuthorName" : authorName,
                            "ReviewDate": reviewDate,
                            "Rating" : reviewRating,
                            "Text" : reviewText
                          ]) { err in
                            if let err = err {
                              print("Error adding document: \(err)")
                            }
                          }
                        }
                      }
                    }
                  }
                  UIImageView.reviewCount += 1
                  print("Processed Yelp \(UIImageView.reviewCount) of \(UIImageView.reviewTotal)")

                } else if status == "Error" {
                  print("Error")
                } else {
                  print("Unknown status:\(status)")
                }
              }
            }
          } catch let error as NSError {
              print("Failed to load: \(error.localizedDescription)")
          }
        }
      } catch {
        print(error)
      }

    }
    
    func updateGooglePlace(googlePlaceId:String?, requestId:String?, documentId:String, updateType:String) {
      var url = URL(string:"about:blank")!
      let headers: HTTPHeaders = ["Content-type": "application/x-www-form-urlencoded", "X-API-KEY": "YXV0aDB8NjQxMDc3ZjRjYjNiYWE4Yjg5M2Y0MmUwfDVkOGZmYzIzNmI"]
      
      if let requestId = requestId {
        url = URL(string: "https://api.app.outscraper.com/requests/\(requestId)")!
      } else if let googlePlaceId = googlePlaceId {
        let fieldList = updateType == "ReviewsData" ? "status,id,reviews_data" : "status,id,phone,working_hours,rating,reviews"   // reservation_links
        url = URL(string: "https://api.app.outscraper.com/maps/reviews-v3?query=\(googlePlaceId)&fields=\(fieldList)&reviewsLimit=5&sort=newest&ignoreEmpty=true")!
      }
      
      do {
        let urlRequest = try URLRequest(url: url, method: .get, headers: headers)
        getData(from: urlRequest) { data, response, error in
          guard let data = data, error == nil else {
            UIImageView.reviewCount += 1
            print("Processed Google \(UIImageView.reviewCount) of \(UIImageView.reviewTotal)")
            return
          }
          do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
              if let status = json["status"] as? String {
                if status == "Pending" {
                  if let id = json["id"] as? String {
                    self.updateGooglePlace(googlePlaceId: googlePlaceId, requestId: id, documentId: documentId, updateType: updateType)
                  }
                } else if status == "Success" {
                  print("Success.")
                  let db = Firestore.firestore()
                  
                  if let jsonData = json["data"] as? [[String:Any]], jsonData.count > 0 {
                    if updateType == "PlaceData" {
                      var updatePhone = ""
                      if let phone = jsonData[0]["phone"] as? String {
                        updatePhone = phone
                        updatePhone = updatePhone.replacingOccurrences(of: "+1 ", with: "").replacingOccurrences(of: "301-", with: "(301) ").replacingOccurrences(of: "240-", with: "(240) ").replacingOccurrences(of: "202-", with: "(202) ")
                      }
                      var updateRating = 0.0
                      if let rating = jsonData[0]["rating"] as? Double {
                        updateRating = rating
                      }
                      var updateReviews = 0
                      if let reviews = jsonData[0]["reviews"] as? Int {
                        updateReviews = reviews
                      }
                      var updateHours = ""
                      if let workingHours = jsonData[0]["working_hours"] as? [String:Any] {
                        var hours = workingHours["Sunday"] as! String
                        hours = "0,\(hours.replacingOccurrences(of: "\\U202f", with: " "));"
                        updateHours = hours
                        hours = workingHours["Monday"] as! String
                        updateHours += "1,\(hours.replacingOccurrences(of: "\\U202f", with: " "));"
                        hours = workingHours["Tuesday"] as! String
                        updateHours += "2,\(hours.replacingOccurrences(of: "\\U202f", with: " "));"
                        hours = workingHours["Wednesday"] as! String
                        updateHours += "3,\(hours.replacingOccurrences(of: "\\U202f", with: " "));"
                        hours = workingHours["Thursday"] as! String
                        updateHours += "4,\(hours.replacingOccurrences(of: "\\U202f", with: " "));"
                        hours = workingHours["Friday"] as! String
                        updateHours += "5,\(hours.replacingOccurrences(of: "\\U202f", with: " "));"
                        hours = workingHours["Saturday"] as! String
                        updateHours += "6,\(hours.replacingOccurrences(of: "\\U202f", with: " "))"
                      }
                      db.collection("WashingtonDC").document(documentId).updateData(["Phone":updatePhone, "Hours":updateHours, "GoogleRating":updateRating, "GoogleReviews":updateReviews])
                    } else {
                      if let reviewsData = jsonData[0]["reviews_data"] as? [[String:Any]] {
                        var acceptedReviewCount = 0
                        for review in reviewsData {
                          var reviewText = review["review_text"] as! String
                          if let ownerAnswer = review["owner_answer"] as? String {
                            reviewText += "<br/><br/><strong>Owner Response</strong><br/><br/>" + ownerAnswer
                          }
                          if reviewText.count > 50 && acceptedReviewCount < 5 {
                            acceptedReviewCount += 1
                            let authorImage = review["author_image"] as! String
                            let authorName = review["author_title"] as! String
                            let reviewRating = review["review_rating"] as! Int
                            let reviewLink = review["review_link"] as! String
                            let reviewDate = (review["review_datetime_utc"] as! String).components(separatedBy: " ")[0]
                            
                            db.collection("GoogleReview").addDocument(data: [
                              "GooglePlaceId" : googlePlaceId!,
                              "AuthorImage" : authorImage,
                              "AuthorName" : authorName,
                              "ReviewDate": reviewDate,
                              "Rating" : reviewRating,
                              "Text" : reviewText,
                              "Link" : reviewLink
                            ]) { err in
                              if let err = err {
                                print("Error adding document: \(err)")
                              }
                            }
                          }
                        }
                      }
                    }
                  }
                  UIImageView.reviewCount += 1
                  print("Processed Google \(UIImageView.reviewCount) of \(UIImageView.reviewTotal)")
                } else if status == "Error" {
                  print("Error")
                }
              }
            }
          } catch let error as NSError {
              print("Failed to load: \(error.localizedDescription)")
          }
        }
      } catch {
        print(error)
      }
    }

    
    func loadCallout(googlePlaceId:String?, requestId:String?) {
      var url = URL(string:"about:blank")!
      let headers: HTTPHeaders = ["Content-type": "application/x-www-form-urlencoded", "X-API-KEY": "YXV0aDB8NjQxMDc3ZjRjYjNiYWE4Yjg5M2Y0MmUwfDVkOGZmYzIzNmI"]
      
      if let googlePlaceId = googlePlaceId {
        let fieldList = "status,id,phone,working_hours,rating,reviews,reviews_data,reservation_links"
        url = URL(string: "https://api.app.outscraper.com/maps/reviews-v3?query=\(googlePlaceId)&fields=\(fieldList)&reviewsLimit=5&sort=newest&ignoreEmpty=true")!
      } else if let requestId = requestId {
        url = URL(string: "https://api.app.outscraper.com/requests/\(requestId)")!
      }
      
      do {
        let urlRequest = try URLRequest(url: url, method: .get, headers: headers)
        getData(from: urlRequest) { data, response, error in
          guard let data = data, error == nil else { return }
          do {
            if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
              if let status = json["status"] as? String {
                if status == "Pending" {
                  if let id = json["id"] as? String {
                    self.loadCallout(googlePlaceId: nil, requestId: id)
                  }
                } else if status == "Success" {
                }
              }
            }
          } catch let error as NSError {
              print("Failed to load: \(error.localizedDescription)")
          }
        }
      } catch {
        print(error)
      }
    }
    
    func getData(from url: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
    }
    
    func setupGoogleRatings(callout:Callout, placePoint:Point) {
      if placePoint.googleRating > 0 {
        let googleStarCount = Int(placePoint.googleRating)
        callout.googleRating.html = String(format: "%.1f", placePoint.googleRating)
        let topConstant = -0.5
        
        if googleStarCount > 0 {
          callout.spacing = 4.0
          callout.reviewsBar.addSubview(callout.googleStar1)
          callout.googleStar1.translatesAutoresizingMaskIntoConstraints = false
          callout.googleStar1.topAnchor.constraint(equalTo: callout.googleRating.topAnchor, constant: topConstant).isActive = true
          callout.googleStar1.leadingAnchor.constraint(equalTo: callout.googleRating.trailingAnchor, constant: callout.spacing).isActive = true
          callout.spacing += 10
          if googleStarCount > 1 {
            callout.reviewsBar.addSubview(callout.googleStar2)
            callout.googleStar2.translatesAutoresizingMaskIntoConstraints = false
            callout.googleStar2.topAnchor.constraint(equalTo: callout.googleRating.topAnchor, constant: topConstant).isActive = true
            callout.googleStar2.leadingAnchor.constraint(equalTo: callout.googleRating.trailingAnchor, constant: callout.spacing).isActive = true
            callout.spacing += 10
            if googleStarCount > 2 {
              callout.reviewsBar.addSubview(callout.googleStar3)
              callout.googleStar3.translatesAutoresizingMaskIntoConstraints = false
              callout.googleStar3.topAnchor.constraint(equalTo: callout.googleRating.topAnchor, constant: topConstant).isActive = true
              callout.googleStar3.leadingAnchor.constraint(equalTo: callout.googleRating.trailingAnchor, constant: callout.spacing).isActive = true
              callout.spacing += 10
              if googleStarCount > 3 {
                callout.reviewsBar.addSubview(callout.googleStar4)
                callout.googleStar4.translatesAutoresizingMaskIntoConstraints = false
                callout.googleStar4.topAnchor.constraint(equalTo: callout.googleRating.topAnchor, constant: topConstant).isActive = true
                callout.googleStar4.leadingAnchor.constraint(equalTo: callout.googleRating.trailingAnchor, constant: callout.spacing).isActive = true
                callout.spacing += 10
                if googleStarCount > 4 {
                  callout.reviewsBar.addSubview(callout.googleStar5)
                  callout.googleStar5.translatesAutoresizingMaskIntoConstraints = false
                  callout.googleStar5.topAnchor.constraint(equalTo: callout.googleRating.topAnchor, constant: topConstant).isActive = true
                  callout.googleStar5.leadingAnchor.constraint(equalTo: callout.googleRating.trailingAnchor, constant: callout.spacing).isActive = true
                  callout.spacing += 10
                }
              }
            }
          }
        }
        if Double(googleStarCount) < placePoint.googleRating {
          callout.reviewsBar.addSubview(callout.googleHalfStar)
          callout.googleHalfStar.translatesAutoresizingMaskIntoConstraints = false
          callout.googleHalfStar.topAnchor.constraint(equalTo: callout.googleRating.topAnchor, constant: topConstant).isActive = true
          callout.googleHalfStar.leadingAnchor.constraint(equalTo: callout.googleRating.trailingAnchor, constant: callout.spacing).isActive = true
          callout.spacing += 10
        }
        callout.googleUserRatingTotal.textFontSize = 11
        callout.googleUserRatingTotal.textColor = .darkGray
        callout.googleUserRatingTotal.html = "(\(placePoint.googleReviews))"
        callout.reviewsBar.addSubview(callout.googleUserRatingTotal)
        callout.googleUserRatingTotal.translatesAutoresizingMaskIntoConstraints = false
        callout.googleUserRatingTotal.topAnchor.constraint(equalTo: callout.googleRating.topAnchor, constant: -2.0).isActive = true
        callout.googleUserRatingTotal.leadingAnchor.constraint(equalTo: callout.reviewsBar.leadingAnchor, constant: callout.userRatingTotalConstant).isActive = true
        
        callout.googleLogo.isUserInteractionEnabled = true
        let googleTapGesture = UITapGestureRecognizer(target: callout.googleLogo, action: #selector(callout.googleLogo.onGoogleTap(_:)))
        callout.googleLogo.addGestureRecognizer(googleTapGesture)
        callout.yelpLogo.isUserInteractionEnabled = true
        let yelpTapGesture = UITapGestureRecognizer(target: callout.yelpLogo, action: #selector(callout.yelpLogo.onYelpTap(_:)))
        callout.yelpLogo.addGestureRecognizer(yelpTapGesture)
      }
    }
    
    func setupYelpRatings(callout:CoSMap.Callout, annotation:MKAnnotation, placePoint:Point) {
      callout.reviewsBar.addSubview(callout.yelpLogo)
      callout.yelpLogo.translatesAutoresizingMaskIntoConstraints = false
      callout.yelpLogo.topAnchor.constraint(equalTo: callout.reviewsBar.topAnchor, constant: 3.0).isActive = true
      callout.yelpLogo.leadingAnchor.constraint(equalTo: callout.reviewsBar.leadingAnchor, constant: 13.0).isActive = true
      callout.yelpRating.textFontSize = 11
      callout.yelpRating.textColor = .darkGray
      callout.yelpRating.html = String(format: "%.1f", placePoint.yelpRating)
      callout.reviewsBar.addSubview(callout.yelpRating)
      callout.yelpRating.translatesAutoresizingMaskIntoConstraints = false
      callout.yelpRating.topAnchor.constraint(equalTo: callout.yelpLogo.topAnchor, constant: 9.0).isActive = true
      callout.yelpRating.leadingAnchor.constraint(equalTo: callout.yelpLogo.trailingAnchor, constant: 3.5).isActive = true
      
      let yelpStarCount = Int(placePoint.yelpRating)
      let topConstant = 0.0
      
      if yelpStarCount > 0 {
        callout.spacing = 4.0
        callout.reviewsBar.addSubview(callout.yelpStar1)
        callout.yelpStar1.translatesAutoresizingMaskIntoConstraints = false
        callout.yelpStar1.topAnchor.constraint(equalTo: callout.yelpRating.topAnchor, constant: topConstant).isActive = true
        callout.yelpStar1.leadingAnchor.constraint(equalTo: callout.yelpRating.trailingAnchor, constant: callout.spacing).isActive = true
        callout.spacing += 10
        if yelpStarCount > 1 {
          callout.reviewsBar.addSubview(callout.yelpStar2)
          callout.yelpStar2.translatesAutoresizingMaskIntoConstraints = false
          callout.yelpStar2.topAnchor.constraint(equalTo: callout.yelpRating.topAnchor, constant: topConstant).isActive = true
          callout.yelpStar2.leadingAnchor.constraint(equalTo: callout.yelpRating.trailingAnchor, constant: callout.spacing).isActive = true
          callout.spacing += 10
          if yelpStarCount > 2 {
            callout.reviewsBar.addSubview(callout.yelpStar3)
            callout.yelpStar3.translatesAutoresizingMaskIntoConstraints = false
            callout.yelpStar3.topAnchor.constraint(equalTo: callout.yelpRating.topAnchor, constant: topConstant).isActive = true
            callout.yelpStar3.leadingAnchor.constraint(equalTo: callout.yelpRating.trailingAnchor, constant: callout.spacing).isActive = true
            callout.spacing += 10
            if yelpStarCount > 3 {
              callout.reviewsBar.addSubview(callout.yelpStar4)
              callout.yelpStar4.translatesAutoresizingMaskIntoConstraints = false
              callout.yelpStar4.topAnchor.constraint(equalTo: callout.yelpRating.topAnchor, constant: topConstant).isActive = true
              callout.yelpStar4.leadingAnchor.constraint(equalTo: callout.yelpRating.trailingAnchor, constant: callout.spacing).isActive = true
              callout.spacing += 10
              if yelpStarCount > 4 {
                callout.reviewsBar.addSubview(callout.yelpStar5)
                callout.yelpStar5.translatesAutoresizingMaskIntoConstraints = false
                callout.yelpStar5.topAnchor.constraint(equalTo: callout.yelpRating.topAnchor, constant: topConstant).isActive = true
                callout.yelpStar5.leadingAnchor.constraint(equalTo: callout.yelpRating.trailingAnchor, constant: callout.spacing).isActive = true
                callout.spacing += 10
              }
            }
          }
        }
      }
      if Float(yelpStarCount) < Float(placePoint.yelpRating) {
        callout.reviewsBar.addSubview(callout.yelpHalfStar)
        callout.yelpHalfStar.translatesAutoresizingMaskIntoConstraints = false
        callout.yelpHalfStar.topAnchor.constraint(equalTo: callout.yelpRating.topAnchor, constant: topConstant).isActive = true
        callout.yelpHalfStar.leadingAnchor.constraint(equalTo: callout.yelpRating.trailingAnchor, constant: callout.spacing).isActive = true
        callout.spacing += 10
      }
      callout.yelpUserRatingTotal.textFontSize = 11
      callout.yelpUserRatingTotal.textColor = .darkGray
      callout.yelpUserRatingTotal.html = "(\(placePoint.yelpReviews))"
      callout.reviewsBar.addSubview(callout.yelpUserRatingTotal)
      callout.yelpUserRatingTotal.translatesAutoresizingMaskIntoConstraints = false
      callout.yelpUserRatingTotal.topAnchor.constraint(equalTo: callout.yelpRating.topAnchor, constant: topConstant - 1.0).isActive = true
      callout.yelpUserRatingTotal.leadingAnchor.constraint(equalTo: callout.reviewsBar.leadingAnchor, constant: callout.userRatingTotalConstant).isActive = true

      Coordinator.yelpAPIClient.searchBusinesses(byTerm: placePoint.name, location: nil, latitude: annotation.coordinate.latitude, longitude: annotation.coordinate.longitude, radius: 1000, categories: nil, locale: nil, limit: 1, offset: nil, sortBy: nil, priceTiers: nil, openNow: nil, openAt: nil, attributes: nil) { business in
        if let business = business {
          if let businesses = business.businesses {
            businesses.forEach { businessSearch in
              if let closed = businessSearch.isClosed {
                if closed == true {
                  callout.openLabel.text = "Closed"
                  callout.openLabel.textColor = #colorLiteral(red: 0.5743096471, green: 0.1235112026, blue: 0.1098221466, alpha: 1)
                } else {
                  callout.openLabel.text = "Open"
                  callout.openLabel.textColor = #colorLiteral(red: 0, green: 0.3435123563, blue: 0, alpha: 1)
                }
              }
            }
          }
        }
      }
    }
    
    func getAreas(_ mapView: MKMapView) {
      let db = Firestore.firestore()
      areaPoints = []

      DispatchQueue.global().async {
        DispatchQueue.main.async {
          self.parent.dataSource.message = "Loading..."
        }
      }
      
      db.collection("\(parent.dataSource.city)Area").getDocuments { queryAreas, err in
        let areas = queryAreas!.documents
        for area in areas {
          let displayName = area.get("DisplayName") as! String
          let markerLocation = area.get("MarkerLocation") as! GeoPoint
          let areaCenter = area.get("AreaCenter") as! GeoPoint
          let zoom = area.get("Zoom") as? Float ?? 20
          let mkPointAnnotation = MKPointAnnotation(__coordinate: CLLocationCoordinate2D(latitude: markerLocation.latitude, longitude: markerLocation.longitude))
          mkPointAnnotation.title = displayName
          var areaPoint = Point(mkPointAnnotation: mkPointAnnotation)
          areaPoint.displayName = displayName
          areaPoint.coordinateLat = markerLocation.latitude
          areaPoint.coordinateLng = markerLocation.longitude
          areaPoint.name = area.get("Name") as! String
          areaPoint.type = "0"
          areaPoint.areaCenterLat = areaCenter.latitude
          areaPoint.areaCenterLng = areaCenter.longitude
          areaPoint.zoom = zoom
          self.areaPoints.append(areaPoint)
          mapView.addAnnotation(mkPointAnnotation)
        }
        self.parent.dataSource.message = ""
      }
    }
    
    func getPlaces(_ mapView: MKMapView, areaTitle: String) {
      parent.dataSource.message = "Loading..."
      placePoints = []
      placeCounter = 1
      let db = Firestore.firestore()
                
      db.collection(parent.dataSource.city).whereField("Area", in: [self.areaName]).getDocuments { queryPlaces, err in
        let places = queryPlaces!.documents
        for place in places {
          let location = place.get("Location") as! GeoPoint
          let mkPointAnnotation = MKPointAnnotation(__coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude))
          var placePoint = Point(mkPointAnnotation: mkPointAnnotation)
          placePoint.name = place.get("Name") as! String
          placePoint.coordinateLat = location.latitude
          placePoint.coordinateLng = location.longitude
          placePoint.address = place.get("Address") as! String
          placePoint.desc = place.get("Description") as! String
          placePoint.notes = place.get("Notes") as! String
          placePoint.type = place.get("Type") as! String
          placePoint.website = place.get("Website") as! String
          placePoint.googlePlaceId = place.get("GooglePlaceId") as! String
          placePoint.yelpPlaceId = place.get("YelpPlaceId") as! String
          placePoint.hours = place.get("Hours") as! String
          placePoint.phone = place.get("Phone") as! String
          placePoint.price = place.get("Price") as! String
          placePoint.googleRating = place.get("GoogleRating") as! Double
          placePoint.googleReviews = place.get("GoogleReviews") as! Int
          placePoint.yelpRating = place.get("YelpRating") as! Double
          placePoint.yelpReviews = place.get("YelpReviews") as! Int
          self.placePoints.append(placePoint)
          let imageName = self.currentImageFolder == "Charleston" ? placePoint.address.replacingOccurrences(of: " ", with: "") : Coordinator.sanitizeImageName(name: placePoint.name)
//          let imagePath = "https://res.cloudinary.com/backyardhiddengems-com/image/upload/f_auto,q_auto/\(self.currentImageFolder)/icons/\(imageName).png"
//          Coordinator.getImageWithURL(urlString: imagePath) { image in
          self.pointImages[imageName] = UIImage(named: "\(self.areaName.replacingOccurrences(of: " ", with: ""))/\(imageName)")
//          }
        }
      }
    }
    
    func updatePlaces(_ mapView: MKMapView) {
      UIImageView.setMapMovementEnabled(enabled: false)
      let annotationsToRemove = mapView.annotations
      
      for var placePoint in self.placePoints {
//          if ["Cork 57", "Euro Motorcars Bethesda"].contains(where: { name in
//            name == placePoint.name
//          }) {
          placePoint.annotation = MKPointAnnotation(__coordinate: CLLocationCoordinate2D(latitude: placePoint.coordinate.latitude, longitude: placePoint.coordinate.longitude))
          mapView.addAnnotation(placePoint.annotation)
//        }
      }
      
      mapView.removeAnnotations(annotationsToRemove)
      let area = areaName.replacingOccurrences(of: " ", with: "")
      var address = "", desc = "", notes = "", website = "", phone = ""
      var latitude = 0.0, longitude = 0.0
      pointImages[area] = UIImage(named: "\(area)/\(area)")
      
      if areaName == "Bethesda Row" {
        latitude = 38.98391
        longitude = -77.09712
        address = "Bethesda/Woodmont/Elm"
        desc = "Downtown shopping"
        notes = "<a href='https://www.bethesdarow.com/contact-us/'>Contact Us</a><br/><div style=\"text-align:left;\"><strong>NEIGHBORHOOD ROOTS. GLOBAL SENSIBILITIES.</strong></div>"
        website = "https://www.bethesdarow.com"
        phone = "877-265-7417"
      } else if areaName == "Westbard Square" {
        latitude = 38.96486
        longitude = -77.10804
        address = "Westbard Ave"
        desc = "Shopping center"
        notes = "<a href='https://westbardsquare.com/leasing-contacts/'>Contacts</a><br/><br/><div style=\"text-align:left;\"><strong>WHERE IT ALL COMES TOGETHER</strong><br/><br/>The Westwood Shopping Center has been a cornerstone of the Bethesda community for generations. At the new Westbard Square, we’re enhancing everything locals love about this treasured neighborhood staple, creating a dynamic gathering place where shoppers can run a quick errand or stay awhile to catch up with family and friends.<br/><br/>Westbard Square is committed to supporting local retailers while providing a desirable neighborhood destination to satisfy shoppers’ daily needs. The addition of a central green will offer scenic gathering spaces and community-focused activities and amenities.</div>"
        website = "https://westbardsquare.com"
        phone = "703-442-4300"
      } else if areaName == "City Center" {
        latitude = 38.90201
        longitude = -77.02559
        address = "I & 11th St NW"
        desc = "Shopping destination"
        notes = ""
        website = "https://www.citycenterdc.com"
        phone = "(202) 289-9000"
      } else if areaName == "Penn Quarter" {
        latitude = 38.89401
        longitude = -77.02401
        address = "Penn Quarter"
        desc = "Upscale Neighborhood"
        notes = "Penn Quarter & Chinatown draws foodies, culture vultures, shoppers and sports fans with something to dig into in these neighborhoods north of Pennsylvania Avenue NW, which is as hopping at night as during the day.  Museum fans can wander the Smithsonian Institution’s National Portrait Gallery and American Art Museum (both housed in the same neoclassical building). Nearby, the United States Navy Memorial pays respect to veterans who served in the U.S. Navy with a commemorative public plaza, symbolic statue of a Lone Sailor and the Naval Heritage Center."
        website = "https://washington.org/dc-neighborhoods/penn-quarter-chinatown"
        phone = ""
      } else if areaName == "Chinatown" {
        latitude = 38.90095
        longitude = -77.02091
        address = "Chinatown"
        desc = "Ethnic neighborhood"
        notes = ""
        website = "https://en.wikipedia.org/wiki/Chinatown_(Washington,_D.C.)"
        phone = ""
      } else if areaName == "Friendship Heights DC" {
        latitude = 38.95902
        longitude = -77.08161
        address = "NW Washington DC"
        desc = "Neighborhood"
        notes = "<div style='text-align:left'><strong>Come meet a friend.</strong><br/><br/>Discover what Friendship Heights has to offer, learn about upcoming activities and the latest neighborhood news, and explore new hidden gems in the neighborhood."
        website = "https://friendshipheights.com"
        phone = ""
      } else if areaName == "Bradley Shopping Center" {
        latitude = 38.97888
        longitude = -77.09955
        address = "6900 Arlington Rd"
        desc = "Shopping center"
        notes = "<a href='mail:info@bradleyshoppingcenter.com'>info@bradleyshoppingcenter.com</a><br/><br/><div style=\"text-align:left;\">Come visit our shops at the Bradley Boulevard Shopping Center. We are located at the corner of Arlington Rd. & Bradley Blvd., in Bethesda.</div>"
        website = "http://bradleyshoppingcenter.com"
        phone = "(301) 654-5309"
      } else if areaName == "Friendship Heights" {
        latitude = 38.96699
        longitude = -77.08739
        address = "Village of Friendship Heights, MD"
        desc = "Residential area"
        notes = "One of the finest communities in the DMV awaits you at Friendship Heights Village."
        website = "https://friendshipheightsmd.gov"
        phone = ""
      }

      if latitude > 0.0 {
        let mkPointAnnotation = MKPointAnnotation(__coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
        var placePoint = Point(mkPointAnnotation: mkPointAnnotation)
        placePoint.name = areaName
        placePoint.coordinateLat = latitude
        placePoint.coordinateLng = longitude
        placePoint.address = address
        placePoint.desc = desc
        placePoint.notes = notes
        placePoint.website = website
        placePoint.phone = phone
        placePoints.append(placePoint)
        mapView.addAnnotation(placePoint.annotation)
      }
      
      UIImageView.setMapMovementEnabled(enabled: true)
    }
    
    func removePlacePoints(_ mapView: MKMapView) {
      mapView.removeAnnotations(mapView.annotations)
      
      for areaPoint in areaPoints {
        let mkPointAnnotation = MKPointAnnotation(__coordinate: CLLocationCoordinate2D(latitude: areaPoint.coordinateLat, longitude: areaPoint.coordinateLng))
        mkPointAnnotation.title = areaPoint.displayName
        mapView.addAnnotation(mkPointAnnotation)
      }
    }

    static func sanitizeImageName(name: String) -> String {
      return name.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "&", with: "").replacingOccurrences(of: ".", with: "").replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "/", with: "").replacingOccurrences(of: "é", with: "e")
    }
    
    static func getImageWithURL(urlString:String,completion: @escaping (_ image:UIImage?) -> Void) {
      guard let url = URL(string: urlString) else {
        print("invalid url")
        completion(nil)
        return
      }
      
      DispatchQueue.global().async {
        if let data = try? Data(contentsOf: url) {
          DispatchQueue.main.async {
            let image = UIImage(data: data, scale: 12)
              completion(image)
          }
        } else {
          print("Error url: \(url)")
          completion(nil)
        }
      }
    }
    
    func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
      if overlay is MKPolyline {
        let routePolyline = overlay as! MKPolyline
        let renderer = MKPolylineRenderer(polyline: routePolyline)
        renderer.strokeColor = UIColor.white
        renderer.lineWidth = 2
        return renderer
      }
      return MKOverlayRenderer()
    }
  }
    
  struct Point: Identifiable, Hashable {
    var annotation: MKPointAnnotation
    let id = UUID()

    init(mkPointAnnotation: MKPointAnnotation) {
      self.annotation = mkPointAnnotation
    }
    
    var coordinate: CLLocationCoordinate2D {
      CLLocationCoordinate2D(latitude: self.coordinateLat, longitude: self.coordinateLng)
    }
    
    var displayName = ""
    var name = ""
    var address = ""
    var desc = ""
    var notes = ""
    var type = ""
    var website = ""
    var coordinateLng = 0.0
    var coordinateLat = 0.0
    var areaCenterLng = 0.0
    var areaCenterLat = 0.0
    var zoom:Float = 20
    var googlePlaceId = ""
    var yelpPlaceId = ""
    var hours = ""
    var phone = ""
    var price = ""
    var googleRating = 0.0
    var googleReviews = 0
    var yelpRating = 0.0
    var yelpReviews = 0
  }
    
  class Callout: UIView {
    public let nameLabel = UniversalLabel(frame: .zero)
    private let addressLabel = UniversalLabel(frame: .zero)
    public let phoneTextView = UITextView(frame: .zero)
    private let descLabel = UniversalLabel(frame: .zero)
    public let openLabel = UILabel(frame: .zero)
    public let hoursLabel = UILabel(frame: .zero)
    public let priceLabel = UILabel(frame: .zero)
    public let notesTextView = UITextView(frame: .zero)
    public let imageView = UIImageView(frame: .zero)
    public let reviewsView = UIView(frame: .zero)
    public let reviewsBar = UIView(frame: .zero)
    public var reviewListScrollView = UIScrollView(frame: .zero)
    public var reviewListView = UIView(frame: .zero) // UIView(frame: .infinite)
    public let placePoint: Point
    private let currentImageFolder: String
    public let labelFontStyle = "<style>html { font-family: Helvetica, Arial, sans-serif; } a:link { color: red; text-decoration: none; }</style>"
    private let linkElement = "<a href='[url]'>[name]</a>"
    public let googleLogo: UIImageView
    public let googleReviewLogo: UIImageView
    public let googleRating = UniversalLabel(frame: .zero)
    public let googleUserRatingTotal = UniversalLabel(frame: .zero)
    public let googleStar1: UIImageView
    public let googleStar2: UIImageView
    public let googleStar3: UIImageView
    public let googleStar4: UIImageView
    public let googleStar5: UIImageView
    public let googleHalfStar: UIImageView
    public let yelpStar1: UIImageView
    public let yelpStar2: UIImageView
    public let yelpStar3: UIImageView
    public let yelpStar4: UIImageView
    public let yelpStar5: UIImageView
    public let yelpHalfStar: UIImageView
    public let yelpRating = UniversalLabel(frame: .zero)
    public let yelpUserRatingTotal = UniversalLabel(frame: .zero)
    private var googleTapGesture = UITapGestureRecognizer()
    public let yelpLogo: UIImageView
    public let yelpReviewLogo: UIImageView
    public var spacing = 4.0
    public var userRatingTotalConstant: CGFloat = 0.0
    public var googleRatingTop: CGFloat = 0.0
    private var hoursLabelTop: CGFloat = 1.2
    public var googleReviews: [PlaceReview]
    public var runningReviewHeight = 0.0
    public var firstReview = true
    public var yelpPlaceId = ""
    private var calloutTimer = Timer()
    
    init(placePoint: Point, currentImageFolder: String) {
      if UIDevice.current.userInterfaceIdiom == .pad {
        yelpLogo = UIImageView(image: UIImage(named: "YelpiPad"))
        yelpReviewLogo = UIImageView(image: UIImage(named: "YelpiPad"))
        googleLogo = UIImageView(image: UIImage(named: "GoogleiPad"))
        googleReviewLogo = UIImageView(image: UIImage(named: "GoogleiPad"))
        googleStar1 = UIImageView(image: UIImage(named: "StariPad"))
        googleStar2 = UIImageView(image: UIImage(named: "StariPad"))
        googleStar3 = UIImageView(image: UIImage(named: "StariPad"))
        self.googleStar4 = UIImageView(image: UIImage(named: "StariPad"))
        self.googleStar5 = UIImageView(image: UIImage(named: "StariPad"))
        self.googleHalfStar = UIImageView(image: UIImage(named: "HalfStariPad"))
        self.yelpStar1 = UIImageView(image: UIImage(named: "StariPad"))
        self.yelpStar2 = UIImageView(image: UIImage(named: "StariPad"))
        self.yelpStar3 = UIImageView(image: UIImage(named: "StariPad"))
        self.yelpStar4 = UIImageView(image: UIImage(named: "StariPad"))
        self.yelpStar5 = UIImageView(image: UIImage(named: "StariPad"))
        self.yelpHalfStar = UIImageView(image: UIImage(named: "HalfStariPad"))
        self.userRatingTotalConstant = 146.0
        self.googleRatingTop = 8.0
        self.hoursLabelTop = 2.7
      } else {
        self.yelpLogo = UIImageView(image: UIImage(named: "Yelp"))
        self.yelpReviewLogo = UIImageView(image: UIImage(named: "Yelp"))
        self.googleLogo = UIImageView(image: UIImage(named: "Google"))
        self.googleReviewLogo = UIImageView(image: UIImage(named: "Google"))
        self.googleStar1 = UIImageView(image: UIImage(named: "Star"))
        self.googleStar2 = UIImageView(image: UIImage(named: "Star"))
        self.googleStar3 = UIImageView(image: UIImage(named: "Star"))
        self.googleStar4 = UIImageView(image: UIImage(named: "Star"))
        self.googleStar5 = UIImageView(image: UIImage(named: "Star"))
        self.googleHalfStar = UIImageView(image: UIImage(named: "HalfStar"))
        self.yelpStar1 = UIImageView(image: UIImage(named: "Star"))
        self.yelpStar2 = UIImageView(image: UIImage(named: "Star"))
        self.yelpStar3 = UIImageView(image: UIImage(named: "Star"))
        self.yelpStar4 = UIImageView(image: UIImage(named: "Star"))
        self.yelpStar5 = UIImageView(image: UIImage(named: "Star"))
        self.yelpHalfStar = UIImageView(image: UIImage(named: "HalfStar"))
        self.userRatingTotalConstant = 141.0
        self.googleRatingTop = 6.0
        self.hoursLabelTop = 1.0
      }
      self.placePoint = placePoint
      self.currentImageFolder = currentImageFolder
      googleReviews = []
      super.init(frame: .zero)
      super.widthAnchor.constraint(equalToConstant: 1210.0).isActive = true
      super.leadingAnchor.constraint(equalToSystemSpacingAfter: super.leadingAnchor, multiplier: 0.5).isActive = true
      setupView()
      isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
      translatesAutoresizingMaskIntoConstraints = false
      leadingAnchor.constraint(equalTo: leadingAnchor, constant: 100.0).isActive = false
      heightAnchor.constraint(equalToConstant: 585).isActive = true
      setupReviewList()
      setupName()
      setupAddress()
      setupDesc()
      setupImageView()
      setupReviews()
      setupNotes()
    }
        
    private func setupReviewList() {
      addSubview(reviewListView)
      reviewListView.backgroundColor = .white // UIColor(patternImage: UIImage(named: "Paper")!)
      reviewListView.translatesAutoresizingMaskIntoConstraints = false
      reviewListView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -10.0).isActive = true
      reviewListView.widthAnchor.constraint(equalToConstant: 280.0).isActive = true
      reviewListView.heightAnchor.constraint(equalToConstant: 1000.0).isActive = true
      reviewListView.isHidden = true
    }
    
    private func setupName() {
      let name = placePoint.name == "Montgomery County Liquor & Wine Hampden Lane" ? "Montgomery County Liquor & Wine" : placePoint.name
      nameLabel.html = placePoint.website == "" ? name : "<a href='\(placePoint.website)'>\(name)</a>"
      nameLabel.isUserInteractionEnabled = true
      nameLabel.numberOfLines = 1
      
      if placePoint.name.count > 28 {
        nameLabel.textFontSize = 14
      } else if placePoint.name.count > 22 {
        nameLabel.textFontSize = 16
      } else if placePoint.name.count > 18 {
        nameLabel.textFontSize = 18
      } else {
        nameLabel.textFontSize = 20
      }
      nameLabel.textFontWeight = .bold
      nameLabel.textAlignment = .left
      nameLabel.linkColor = .init(red: 0.1, green: 0.1, blue: 0.75, alpha: 1.0)
      nameLabel.lineBreakMode = .byWordWrapping
      nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
      nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
      
      nameLabel.onPress { url in
        guard let url = url else { return }
        UIApplication.shared.open(url)
      }
      
      addSubview(nameLabel)
      nameLabel.translatesAutoresizingMaskIntoConstraints = false
      nameLabel.topAnchor.constraint(equalTo: topAnchor).isActive = true
      nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4.0).isActive = true
      nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 4.0).isActive = true
    }
    
    private func setupAddress() {
      addressLabel.textFontSize = 12
      addressLabel.textFontWeight = .bold
//      addressLabel.textColor = .gray
      addressLabel.html = placePoint.address
      addSubview(addressLabel)
      addressLabel.translatesAutoresizingMaskIntoConstraints = false
      addressLabel.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 8).isActive = true
      addressLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4.0).isActive = true
      addressLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 4.0).isActive = true
      addSubview(phoneTextView)
      phoneTextView.dataDetectorTypes = UIDataDetectorTypes.phoneNumber
      phoneTextView.translatesAutoresizingMaskIntoConstraints = false
      phoneTextView.topAnchor.constraint(equalTo: nameLabel.bottomAnchor, constant: 0.0).isActive = true
      phoneTextView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 173.0).isActive = true
      phoneTextView.widthAnchor.constraint(equalToConstant: 120.0).isActive = true
      phoneTextView.heightAnchor.constraint(equalToConstant: 30.0).isActive = true
      phoneTextView.backgroundColor = .clear
      phoneTextView.isEditable = false
      phoneTextView.text = placePoint.phone
    }

    private func setupDesc() {
      descLabel.textFontSize = 12
      descLabel.textColor = .black
      descLabel.backgroundColor = .clear
      descLabel.html = placePoint.desc
      addSubview(descLabel)
      descLabel.translatesAutoresizingMaskIntoConstraints = false
      descLabel.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 8.0).isActive = true
      descLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4.0).isActive = true
      descLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 4.0).isActive = true
      addSubview(openLabel)
      openLabel.font = UIFont(name: "HelveticaNeue", size: 12.0)
      openLabel.translatesAutoresizingMaskIntoConstraints = false
      openLabel.topAnchor.constraint(equalTo: addressLabel.bottomAnchor, constant: 7.5).isActive = true
      openLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 139.0).isActive = true
      addSubview(hoursLabel)
      hoursLabel.font = UIFont(name: "HelveticaNeue", size: 10.0)
      hoursLabel.translatesAutoresizingMaskIntoConstraints = false
      hoursLabel.topAnchor.constraint(equalTo: phoneTextView.bottomAnchor, constant: hoursLabelTop).isActive = true
      hoursLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 169.0).isActive = true
      hoursLabel.widthAnchor.constraint(equalToConstant: 90.0).isActive = true
      hoursLabel.textAlignment = .right
      hoursLabel.text = getHoursOpen(hours: placePoint.hours)
    }
    
    private func setupImageView() {
      let imageName = currentImageFolder == "Charleston" ? placePoint.address.replacingOccurrences(of: " ", with: "_") : Coordinator.sanitizeImageName(name: placePoint.name)
      let imageNumber = currentImageFolder == "Washington%20DC" ? "1" : ""
      let imagePath = "https://res.cloudinary.com/backyardhiddengems-com/image/upload/\(currentImageFolder)/\(imageName)\(imageNumber).png"
      Coordinator.getImageWithURL(urlString: imagePath) { image in
        DispatchQueue.main.async {
          self.imageView.image = image
        }
      }
      imageView.contentMode = .scaleAspectFill
      imageView.clipsToBounds = true
      addSubview(imageView)
      imageView.translatesAutoresizingMaskIntoConstraints = false
      imageView.topAnchor.constraint(equalTo: descLabel.bottomAnchor, constant: 8).isActive = true
      imageView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -10.0).isActive = true
      imageView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 10.0).isActive = true
      imageView.heightAnchor.constraint(equalToConstant: 240).isActive = true
      imageView.widthAnchor.constraint(equalToConstant: 280).isActive = true
    }
    
    public func setupReviews() {
      addSubview(reviewsBar)
      reviewsBar.translatesAutoresizingMaskIntoConstraints = false
      reviewsBar.backgroundColor = .white
      reviewsBar.topAnchor.constraint(equalTo: self.imageView.bottomAnchor).isActive = true
      reviewsBar.leadingAnchor.constraint(equalTo: leadingAnchor, constant: -10.0).isActive = true
      reviewsBar.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 10.0).isActive = true
      reviewsBar.heightAnchor.constraint(equalToConstant: 63).isActive = true
      reviewsBar.widthAnchor.constraint(equalToConstant: 280).isActive = true
      reviewsBar.addSubview(priceLabel)
      priceLabel.translatesAutoresizingMaskIntoConstraints = false
      priceLabel.topAnchor.constraint(equalTo: reviewsBar.topAnchor, constant: 7.0).isActive = true
      priceLabel.leadingAnchor.constraint(equalTo: reviewsBar.leadingAnchor, constant: 245.0).isActive = true
      priceLabel.font = UIFont(name: "Helvetica", size: 12.0)
      priceLabel.text = placePoint.price
      reviewsBar.addSubview(googleLogo)
      googleLogo.translatesAutoresizingMaskIntoConstraints = false
      googleLogo.topAnchor.constraint(equalTo: reviewsBar.topAnchor, constant: 34.0).isActive = true
      googleLogo.widthAnchor.constraint(equalToConstant: 48.0).isActive = true
      googleLogo.leadingAnchor.constraint(equalTo: reviewsBar.leadingAnchor, constant: 14.0).isActive = true
      googleRating.textFontSize = 11
      googleRating.textColor = .darkGray
      reviewsBar.addSubview(googleRating)
      googleRating.translatesAutoresizingMaskIntoConstraints = false
      googleRating.topAnchor.constraint(equalTo: googleLogo.topAnchor, constant: googleRatingTop).isActive = true
      googleRating.leadingAnchor.constraint(equalTo: googleLogo.trailingAnchor, constant: 5.0).isActive = true
    }
    
    public func getHoursOpen(hours: String) -> String {
      let daysHours = hours.components(separatedBy: ";")
      
      for dayHours in daysHours {
        let hoursInfo = dayHours.components(separatedBy: ",")
        if hoursInfo[0] == String(Date().dayNumberOfWeek()) {
          return hoursInfo[1]
        }
      }
      
      return "hours unknown"
    }

    
    public func checkScraperStatus(id:String) {
      let urlStatus = URL(string: "https://api.app.outscraper.com/requests/\(id)")!
      let headers: HTTPHeaders = ["Content-type": "application/x-www-form-urlencoded", "X-API-KEY": "YXV0aDB8NjQxMDc3ZjRjYjNiYWE4Yjg5M2Y0MmUwfDVkOGZmYzIzNmI"]
      
//      calloutTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(checkStatus), userInfo: nil, repeats: true)

      do {
        let urlRequestStatus = try URLRequest(url: urlStatus, method: .get, headers: headers)
        getData(from: urlRequestStatus) { dataStatus, responseStatus, errorStatus in
          guard let dataStatus = dataStatus, errorStatus == nil else { return }
          do {
            if let json = try JSONSerialization.jsonObject(with: dataStatus, options: []) as? [String: Any] {
              print(json)
              if json["data"] == nil {
                self.checkScraperStatus(id: id)
              }
            }
          } catch let error as NSError {
              print("Failed to load: \(error.localizedDescription)")
          }
        }
      } catch {
        print(error)
      }
      
    }
    
    func getData(from url: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
    }

    @objc func checkStatus() {
      print("fired")
    }
    
    private func setupNotes() {
      notesTextView.textColor = .black
      notesTextView.font = UIFont(name: "HelveticaNeue", size: 10.0)
      notesTextView.backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
      notesTextView.layer.borderWidth = 0.3
      notesTextView.layer.borderColor = CGColor(gray: 0.5, alpha: 1.0)
      notesTextView.textContainerInset = UIEdgeInsets(top: 5, left: 2, bottom: 2, right: 2)
      let notes = "\(labelFontStyle)\(placePoint.notes)"
      notesTextView.attributedText = notes.htmlToAttributedString
      notesTextView.isEditable = false
      addSubview(notesTextView)
      notesTextView.translatesAutoresizingMaskIntoConstraints = false
      notesTextView.topAnchor.constraint(equalTo: imageView.bottomAnchor, constant: 63).isActive = true
//      notesTextView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4.0).isActive = true
//      notesTextView.trailingAnchor.constraint(equalTo: leadingAnchor, constant: 4.0).isActive = true
      notesTextView.heightAnchor.constraint(equalToConstant: 200.0).isActive = true
      notesTextView.bottomAnchor.constraint(equalTo: bottomAnchor).isActive = true
      notesTextView.widthAnchor.constraint(equalToConstant: 260.0).isActive = true
    }
  }
}

class LocationViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var authorizationStatus: CLAuthorizationStatus

    private let locationManager: CLLocationManager

    override init() {
        locationManager = CLLocationManager()
        authorizationStatus = locationManager.authorizationStatus

        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.startUpdatingLocation()
    }

    func requestPermission() {
        locationManager.requestWhenInUseAuthorization()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
    }
}

class PlaceAnnotation: MKPointAnnotation {
  var name: String
  var address: String
  var desc: String
  var notes: String
  var type: String
  
  init(name: String, address: String, desc: String, notes: String, type: String) {
    self.name = name
    self.address = address
    self.desc = desc
    self.notes = "<div style='font-family: Helvetica, Arial, sans-serif;font-size: 82%;'>\(notes)</div>"
    self.type = type
  }
}

class PlaceMarkerAnnotationView: MKMarkerAnnotationView {
  var placeName = ""
  var placeAddress = ""
  var googlePlaceId = ""
 
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
    super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
  }
  override var annotation: MKAnnotation? {
      willSet {
          displayPriority = MKFeatureDisplayPriority.required
      }
  }
}

struct PlaceDetail: Decodable {
  let name: String
  let reviews: [PlaceReview]
}

struct YelpReviewDetail: Decodable {
  let success: Bool
  let url: String
  let page: Int
  let total_results: Int
  let no_of_pages: Int
  let result_count: Int
  let reviews: [YelpReview]
  let meta_data: DetailMetadata
}

struct YelpReview: Decodable {
  let id: String
  let date: String
  let rating: Int
  let review_title: String
  let review_text: String
  let review_url: String
  let lang: String
  let author_avatar: String
  let author_url: String
  let author_name: String
  let meta_data: YelpReviewMetadata
  let location: String
  let response: String
}

struct PlaceReview: Decodable {
    let author_name: String
    let profile_photo_url: String
    let rating: Int
    let relative_time_description: String
    let text: String
}

struct DecodableType: Decodable {
  let result: PlaceDetail
}

struct YelpDecodableType: Decodable {
  let result: YelpReviewDetail
}

struct YelpReviewMetadata: Decodable {
  let author_contributions: Int
  let feedback: Feedback
}

struct DetailMetadata: Decodable {
  let lang: String
  let lang_stats: [LangStats]
}

struct ReviewMetadata: Decodable {
  let author_contributions: Int
  let feedback: Feedback
}

struct Feedback: Decodable {
  let useful: Int
  let funny: Int
  let cool: Int
}

struct LangStats: Decodable {
  let code: String
  let count: Int
}

extension UIImage {
  func imageScaledToSize(size : CGSize, isOpaque : Bool) -> UIImage {
      // begin a context of the desired size
      UIGraphicsBeginImageContextWithOptions(size, isOpaque, 0.0)
      // draw image in the rect with zero origin and size of the context
      let imageRect = CGRect(origin: CGPointZero, size: size)
      self.draw(in: imageRect)
      // get the scaled image, close the context and return the image
      let scaledImage = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()

      return scaledImage!
  }
}

extension String {
    var htmlToAttributedString: NSAttributedString? {
        guard let data = data(using: .utf8) else { return nil }
        do {
          return try NSAttributedString(data: data, options: [.documentType: NSAttributedString.DocumentType.html, .characterEncoding:String.Encoding.utf8.rawValue], documentAttributes: nil)
        } catch {
            return nil
        }
    }
    var htmlToString: String {
        return htmlToAttributedString?.string ?? ""
    }
}

extension Date {
    func dayNumberOfWeek() -> Int {
        return Calendar.current.dateComponents([.weekday], from: self).weekday! - 1
    }
}

extension UIImageView
{
  public static var reviewTop = 0.0
  public static var reviewCount = 0
  public static var reviewTotal = 0
  
  public static func setMapMovementEnabled(enabled:Bool) {
    CoSMap.mapView.isScrollEnabled = enabled
    CoSMap.mapView.isZoomEnabled = enabled
    CoSMap.mapView.isPitchEnabled = enabled
    CoSMap.mapView.isRotateEnabled = enabled
  }
  
  @objc public func onGoogleTap(_ recognizer: UITapGestureRecognizer) {
    if let callout = recognizer.view?.superview?.superview as? CoSMap.Callout {
      for view in callout.reviewListView.subviews {
        view.removeFromSuperview()
      }

      UIImageView.reviewTop = 13.0
      callout.reviewListView.isHidden = false
      callout.reviewListView.layer.zPosition = 1
      let db = Firestore.firestore()
                
      db.collection("GoogleReview").whereField("GooglePlaceId", in: [callout.placePoint.googlePlaceId]).getDocuments { queryReview, err in
        let reviews = queryReview!.documents
        
        if reviews.count == 0 {
          self.noReviewsBar(callout: callout)
        } else {
          UIImageView.setMapMovementEnabled(enabled: false)
          UIImageView.reviewTotal = reviews.count
          UIImageView.reviewCount = 0
          callout.runningReviewHeight = 0.0
          callout.firstReview = true
          let recentLabel = UILabel(frame: .zero)
          callout.reviewListView.addSubview(recentLabel)
          recentLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 12.0)
          recentLabel.textColor = .black
          recentLabel.translatesAutoresizingMaskIntoConstraints = false
          recentLabel.topAnchor.constraint(equalTo: callout.reviewListView.topAnchor, constant: -5.0).isActive = true
          recentLabel.leadingAnchor.constraint(equalTo: callout.reviewListView.leadingAnchor, constant: 10.0).isActive = true
          recentLabel.widthAnchor.constraint(equalToConstant: 150.0).isActive = true
          recentLabel.textAlignment = .left
          recentLabel.text = "Recent                 reviews"
          
          callout.reviewListView.addSubview(callout.googleReviewLogo)
          callout.googleReviewLogo.translatesAutoresizingMaskIntoConstraints = false
          callout.googleReviewLogo.topAnchor.constraint(equalTo: callout.reviewListView.topAnchor, constant: -10.0).isActive = true
          callout.googleReviewLogo.leadingAnchor.constraint(equalTo: callout.reviewListView.leadingAnchor, constant: 55.0).isActive = true
          
          for review in reviews {
            let authorName = review["AuthorName"] as? String ?? ""
            let reviewDate = review["ReviewDate"] as? String ?? ""
            let rating = review["Rating"] == nil ? 0.0 : CGFloat(review["Rating"] as! Double)
            let text = review["Text"] as? String ?? ""
            if let authorImage = review["AuthorImage"] as? String {
              if let authorImageURL = URL(string: authorImage) {
                self.getData(from: URLRequest(url: authorImageURL)) { data, response, error in
                  guard let data = data, error == nil else { return }
                  DispatchQueue.main.async() {
                    let image = UIImage(data: data, scale: 4.0)!
                    self.loadReview(callout: callout, name: authorName, rating: rating, reviewDate: reviewDate, text: text, image: image, source: "Google")
                  }
                }
              }
            } else {
              DispatchQueue.main.async() {
                self.loadReview(callout: callout, name: authorName, rating: rating, reviewDate: reviewDate, text: text, image: UIImage(), source: "Google")
              }
            }
          }
        }
      }
    }
  }
  
  @objc public func onYelpTap(_ recognizer: UITapGestureRecognizer) {
    if let callout = recognizer.view?.superview?.superview as? CoSMap.Callout {
      for view in callout.reviewListView.subviews {
        view.removeFromSuperview()
      }

      UIImageView.reviewTop = 13.0
      callout.reviewListView.isHidden = false
      callout.reviewListView.layer.zPosition = 1
      let db = Firestore.firestore()
      
      db.collection("YelpReview").whereField("YelpPlaceId", in: [callout.placePoint.yelpPlaceId]).getDocuments { queryReview, err in
        let reviews = queryReview!.documents
        if reviews.count == 0 {
          self.noReviewsBar(callout: callout)
        } else {
          UIImageView.setMapMovementEnabled(enabled: false)
          UIImageView.reviewTotal = reviews.count
          UIImageView.reviewCount = 0
          callout.runningReviewHeight = 0.0
          callout.firstReview = true
          let recentLabel = UILabel(frame: .zero)
          callout.reviewListView.addSubview(recentLabel)
          recentLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 12.0)
          recentLabel.textColor = .black
          recentLabel.translatesAutoresizingMaskIntoConstraints = false
          recentLabel.topAnchor.constraint(equalTo: callout.reviewListView.topAnchor, constant: -2.0).isActive = true
          recentLabel.leadingAnchor.constraint(equalTo: callout.reviewListView.leadingAnchor, constant: 12.0).isActive = true
          recentLabel.widthAnchor.constraint(equalToConstant: 150.0).isActive = true
          recentLabel.textAlignment = .left
          recentLabel.text = "Recent                  reviews"
          
          callout.reviewListView.addSubview(callout.yelpReviewLogo)
          callout.yelpReviewLogo.translatesAutoresizingMaskIntoConstraints = false
          callout.yelpReviewLogo.topAnchor.constraint(equalTo: callout.reviewListView.topAnchor, constant: -10.0).isActive = true
          callout.yelpReviewLogo.leadingAnchor.constraint(equalTo: callout.reviewListView.leadingAnchor, constant: 55.0).isActive = true
          
          if reviews.count == 0 {
            self.noReviewsBar(callout: callout)
          } else {
            for review in reviews {
              let authorName = review["AuthorName"] as? String ?? ""
              let reviewDate = review["ReviewDate"] as? String ?? ""
              let rating = review["Rating"] == nil ? 0.0 : CGFloat(review["Rating"] as! Double)
              let text = review["Text"] as? String ?? ""
              self.loadReview(callout: callout, name: authorName, rating: rating, reviewDate: reviewDate, text: text, image: UIImage(), source: "Yelp")
            }
          }
        }
      }
    }
  }
  
  func noReviewsBar(callout:CoSMap.Callout) {
    let reviewBar = UIView(frame: .zero)
    callout.reviewListView.addSubview(reviewBar)
    reviewBar.translatesAutoresizingMaskIntoConstraints = false
    reviewBar.backgroundColor = .white
    reviewBar.topAnchor.constraint(equalTo: callout.reviewListView.topAnchor, constant: UIImageView.reviewTop).isActive = true
    reviewBar.leadingAnchor.constraint(equalTo: callout.reviewListView.leadingAnchor, constant: 0.0).isActive = true
    reviewBar.widthAnchor.constraint(equalTo: callout.reviewListView.widthAnchor).isActive = true
    reviewBar.heightAnchor.constraint(equalToConstant: 40.0).isActive = true
    callout.nameLabel.isUserInteractionEnabled = false
    callout.phoneTextView.isUserInteractionEnabled = false
    callout.notesTextView.isUserInteractionEnabled = false
    let backButton = UIButton(primaryAction: UIAction(handler: { _ in
      callout.reviewListView.isHidden = true
      callout.nameLabel.isUserInteractionEnabled = true
      callout.phoneTextView.isUserInteractionEnabled = true
      callout.notesTextView.isUserInteractionEnabled = true
      UIImageView.setMapMovementEnabled(enabled: true)
    }))
    let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
    backButton.setImage(UIImage(systemName: "chevron.backward.circle.fill", withConfiguration: configuration), for: .normal)
    reviewBar.addSubview(backButton)
    backButton.translatesAutoresizingMaskIntoConstraints = false
    backButton.tintColor = .black
    backButton.topAnchor.constraint(equalTo: reviewBar.topAnchor, constant: 0.0).isActive = true
    backButton.leadingAnchor.constraint(equalTo: reviewBar.leadingAnchor, constant: 230.0).isActive = true
    backButton.widthAnchor.constraint(equalToConstant: 32.0).isActive = true
    backButton.heightAnchor.constraint(equalToConstant: 32.0).isActive = true
    let noReviewsTodayLabel = UILabel(frame: .zero)
    callout.reviewListView.addSubview(noReviewsTodayLabel)
    noReviewsTodayLabel.font = UIFont(name: "HelveticaNeue", size: 12.0)
    noReviewsTodayLabel.textColor = .black
    noReviewsTodayLabel.translatesAutoresizingMaskIntoConstraints = false
    noReviewsTodayLabel.topAnchor.constraint(equalTo: callout.reviewListView.topAnchor, constant: 20.0).isActive = true
    noReviewsTodayLabel.leadingAnchor.constraint(equalTo: callout.reviewListView.leadingAnchor, constant: 20.0).isActive = true
    noReviewsTodayLabel.widthAnchor.constraint(equalToConstant: 200.0).isActive = true
    noReviewsTodayLabel.textAlignment = .left
    noReviewsTodayLabel.text = "No reviews are available today."
  }
  
  func loadReview(callout:CoSMap.Callout, name:String, rating:CGFloat, reviewDate:String, text:String, image:UIImage, source:String) {
    let reviewBar = UIView(frame: .zero)
    callout.reviewListView.addSubview(reviewBar)
    reviewBar.translatesAutoresizingMaskIntoConstraints = false
    reviewBar.backgroundColor = .white
    reviewBar.topAnchor.constraint(equalTo: callout.reviewListView.topAnchor, constant: UIImageView.reviewTop).isActive = true
    reviewBar.leadingAnchor.constraint(equalTo: callout.reviewListView.leadingAnchor, constant: 0.0).isActive = true
    reviewBar.widthAnchor.constraint(equalTo: callout.reviewListView.widthAnchor).isActive = true
    reviewBar.heightAnchor.constraint(equalToConstant: 40.0).isActive = true
    let indent = source == "Google" ? 60.0 : 20.0
    
    if callout.firstReview == true {
      callout.nameLabel.isUserInteractionEnabled = false
      callout.phoneTextView.isUserInteractionEnabled = false
      callout.notesTextView.isUserInteractionEnabled = false
      let backButton = UIButton(primaryAction: UIAction(handler: { _ in
        callout.reviewListView.isHidden = true
        callout.nameLabel.isUserInteractionEnabled = true
        callout.phoneTextView.isUserInteractionEnabled = true
        callout.notesTextView.isUserInteractionEnabled = true
        UIImageView.setMapMovementEnabled(enabled: true)
      }))
      let configuration = UIImage.SymbolConfiguration(pointSize: 22, weight: .medium)
      backButton.setImage(UIImage(systemName: "chevron.backward.circle.fill", withConfiguration: configuration), for: .normal)
      reviewBar.addSubview(backButton)
      backButton.translatesAutoresizingMaskIntoConstraints = false
      backButton.tintColor = .black
      backButton.topAnchor.constraint(equalTo: reviewBar.topAnchor, constant: 0.0).isActive = true
      backButton.leadingAnchor.constraint(equalTo: reviewBar.leadingAnchor, constant: 230.0).isActive = true
      backButton.widthAnchor.constraint(equalToConstant: 32.0).isActive = true
      backButton.heightAnchor.constraint(equalToConstant: 32.0).isActive = true
      callout.firstReview = false
    }
    
    let profileImageView = UIImageView(image: image)
    reviewBar.addSubview(profileImageView)
    profileImageView.translatesAutoresizingMaskIntoConstraints = false
    profileImageView.topAnchor.constraint(equalTo: reviewBar.topAnchor, constant: 5.0).isActive = true
    profileImageView.leadingAnchor.constraint(equalTo: reviewBar.leadingAnchor, constant: 10.0).isActive = true
    let author = UILabel(frame: .zero)
    reviewBar.addSubview(author)
    author.font = UIFont(name: "HelveticaNeue", size: 10.0)
    author.translatesAutoresizingMaskIntoConstraints = false
    author.topAnchor.constraint(equalTo: reviewBar.topAnchor, constant: 5.0).isActive = true
    author.leadingAnchor.constraint(equalTo: reviewBar.leadingAnchor, constant: indent).isActive = true
    author.widthAnchor.constraint(equalToConstant: 200.0).isActive = true
    author.textAlignment = .left
    author.text = name
    UIImageView.reviewTop += 40.0
    UIImageView.reviewCount += 1
    var starCount = Int(rating)
    let starImageName = UIDevice.current.userInterfaceIdiom == .pad ? "StariPad" : "Star"
    let halfStarImageName = UIDevice.current.userInterfaceIdiom == .pad ? "HalfStariPad" : "HalfStar"
    var starLead = source == "Google" ? 20.0 : indent - 11

    while starCount > 0 {
      let starImageView = UIImageView(image: UIImage(named: starImageName))
      reviewBar.addSubview(starImageView)
      starImageView.translatesAutoresizingMaskIntoConstraints = false
      starImageView.topAnchor.constraint(equalTo: author.bottomAnchor).isActive = true
      starImageView.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: starLead).isActive = true
      starLead += 10
      starCount -= 1
    }
    
    if rating > CGFloat(Int(rating)) {
      let halfStarImageView = UIImageView(image: UIImage(named: halfStarImageName))
      reviewBar.addSubview(halfStarImageView)
      halfStarImageView.translatesAutoresizingMaskIntoConstraints = false
      halfStarImageView.topAnchor.constraint(equalTo: author.bottomAnchor).isActive = true
      halfStarImageView.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: starLead).isActive = true
    }
    
    let relativeTimeLabel = UILabel(frame: .zero)
    reviewBar.addSubview(relativeTimeLabel)
    relativeTimeLabel.font = UIFont(name: "HelveticaNeue", size: 10.0)
    relativeTimeLabel.translatesAutoresizingMaskIntoConstraints = false
    relativeTimeLabel.topAnchor.constraint(equalTo: reviewBar.topAnchor, constant: 28.0).isActive = true
    relativeTimeLabel.leadingAnchor.constraint(equalTo: reviewBar.leadingAnchor, constant: indent).isActive = true
    relativeTimeLabel.widthAnchor.constraint(equalToConstant: 200.0).isActive = true
    relativeTimeLabel.textAlignment = .left
    relativeTimeLabel.text = reviewDate

    let reviewTextView = UITextView()
    callout.reviewListView.addSubview(reviewTextView)
    reviewTextView.font = UIFont(name: "Helvetica", size: 12.0)
    reviewTextView.textColor = .black
    reviewTextView.backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.97, alpha: 1.0)
    reviewTextView.layer.borderWidth = 0.3
    reviewTextView.layer.borderColor = CGColor(gray: 0.5, alpha: 1.0)
    reviewTextView.textContainerInset = UIEdgeInsets(top: 2, left: 2, bottom: 2, right: 2)
    reviewTextView.isEditable = false
    let reviewText = "\(callout.labelFontStyle)\(text.replacingOccurrences(of: "\n", with: " "))"
    reviewTextView.attributedText = reviewText.htmlToAttributedString
    reviewTextView.translatesAutoresizingMaskIntoConstraints = false
    reviewTextView.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 5.0).isActive = true
    reviewTextView.topAnchor.constraint(equalTo: reviewBar.bottomAnchor, constant: 5.0).isActive = true
    reviewTextView.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
    reviewTextView.widthAnchor.constraint(equalToConstant: 240.0).isActive = true
    reviewTextView.heightAnchor.constraint(equalToConstant: 66.0).isActive = true

    UIImageView.reviewTop += 74
    
    if Int(UIImageView.reviewTotal) == UIImageView.reviewCount {
      callout.reviewListView.isHidden = false
      callout.reviewListView.layer.zPosition = 1
    }
  }
  
  @objc func touchedReview() {
    print("touched review")
  }
  
  func getData(from url: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
      URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
  }
}

extension UILabel {
  func lineCount() -> Int {
      return Int(ceil(self.bounds.width / self.font.lineHeight))
  }
}


