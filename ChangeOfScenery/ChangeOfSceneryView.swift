//
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
// import GooglePlaces
import CDYelpFusionKit
import Alamofire

struct ChangeOfSceneryView: View {
  @ObservedObject var dataSource = DataSource()
  @State public var longPressedLocation: LongPressedLocation?
  @State public var showStreetView = false
  @State public var coordinate: CLLocationCoordinate2D?
  @State public var cosStreetView = CoSStreetView()
  @State public var isHidden = false
  @State private var showingAlert = false
  @State private var showingReviewUpdate = false
  @State private var showingYelpUpdate = false
  @State private var showingGoogleUpdate = false
  @State private var showingYelpRefresh = false
  @State private var showingGoogleRefresh = false
  @State private var googlePlaceId = ""
  @State private var yelpPlaceId = ""
  @State private var reviewArea = "Hingham Shipyard"
  @State private var documentName = ""
  @State private var addPlaceLabel = "Add Place"
 
  var body: some View {
    let cosMap = CoSMap(dataSource: dataSource, longPressedLocation: $longPressedLocation, showStreetView: $showStreetView, coordinate: $coordinate, streetView: $cosStreetView, isHidden: $isHidden)
        
    ZStack {
      cosStreetView
        .zIndex(showStreetView == true ? 1 : 0)
      
      cosMap
        .zIndex(showStreetView == true ? 0 : 1)
        .edgesIgnoringSafeArea(.all)
        .analyticsScreen(name: "ChangeOfSceneryView")
        .toolbar {
          ToolbarItem(placement: .primaryAction) {
//            Button {
//              setMessage("zoom!")
//            } label: {
//              Label(
//                title: { },
//                icon: {Image(systemName: "plus.circle.fill").foregroundColor(.white)}
//              )
//            }
//          }

//            Menu {
//              Button("Washington DC") {
//                dataSource.city = "WashingtonDC"
//              }
//              Button("Boston MA") {
//                dataSource.city = "Boston"
//              }
//              Button("Charleston SC") {
//                dataSource.city = "Charleston"
//              }
//              Button("Contact Us") {
//                showingAlert = true
//              }
//            } label: {
//              Label(
//                title: { },
//                icon: {Image(systemName: "ellipsis.circle.fill").foregroundColor(.white)}
//              )
//            }
          }
          
//          ToolbarItem(placement: .bottomBar) {
//            Button("Update Reviews") {
//              showingReviewUpdate.toggle()
//            }
//            .alert("Update Reviews", isPresented: $showingReviewUpdate) {
//              TextField("Area", text: $reviewArea)
//              Button("OK", action: loadReviews)
//            }
//          }
          
          if dataSource.level != "area" {
            ToolbarItem(placement: .cancellationAction) {
              Button {
                dataSource.level = showStreetView == true ? "streetview" : "area"
                dataSource.filter = ""
                CoSMap.lastDistance = 0.0
                CoSMap.mapView.isZoomEnabled = true
              } label: {
                Image(systemName: "chevron.backward.circle.fill").foregroundColor(.black)
              }
            }
            if CoSMap.areaName == "Woodmont Triangle" || CoSMap.areaName == "Bethesda Row" || CoSMap.areaName.starts(with: "Friendship Heights") || CoSMap.areaName == "Wildwood" || CoSMap.areaName == "Bradley Shopping Center" || CoSMap.areaName == "Kenwood" || CoSMap.areaName == "Westbard Square" || CoSMap.areaName == "Sumner Place" || CoSMap.areaName == "Spring Valley" {
              ToolbarItem(placement: .primaryAction)
              {
                Button {
                  dataSource.filter = ""
                  cosMap.getPlaces(CoSMap.mapView, areaTitle: CoSMap.areaName, updateAnnotations: true)
                } label: {
                  Image(systemName: "arrow.uturn.backward.circle.fill").foregroundColor(.black)
                }
              }
              ToolbarItem(placement: .primaryAction)
              {
                Button {
                  dataSource.filter = "1"
                  cosMap.getPlaces(CoSMap.mapView, areaTitle: CoSMap.areaName, updateAnnotations: true)
                } label: {
                  Image(systemName: "fork.knife.circle.fill").foregroundColor(.black)
                }
              }
              ToolbarItem(placement: .primaryAction)
              {
                Button {
                  dataSource.filter = "2"
                  cosMap.getPlaces(CoSMap.mapView, areaTitle: CoSMap.areaName, updateAnnotations: true)
                } label: {
                  Image(systemName: "bag.circle.fill").foregroundColor(.black)
                }
              }
              ToolbarItem(placement: .primaryAction)
              {
                Button {
                  dataSource.filter = "9"
                  cosMap.getPlaces(CoSMap.mapView, areaTitle: CoSMap.areaName, updateAnnotations: true)
                } label: {
                  Image(systemName: "scissors.circle.fill").foregroundColor(.black)
                }
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
        .zIndex(1.0)
    }
    .alert(isPresented: $showingAlert) {
        return Alert(title: Text("Contact Info"), message: Text("info@changeofscenery.info"), dismissButton: .default(Text("OK")))
    }
  }
  
  func setMessage(_ message:String) {
    DispatchQueue.global().async {
      DispatchQueue.main.async {
        dataSource.message = message
      }
    }
  }
  
  func getData(from url: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
      URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
  }
  
  func updateGoogleData(googlePlaceId:String, requestId:String?, updateType:String, documentId:String, area:String) {
    var url = URL(string:"about:blank")!
    let headers: HTTPHeaders = ["Content-type": "application/x-www-form-urlencoded", "X-API-KEY": "YXV0aDB8NjQxMDc3ZjRjYjNiYWE4Yjg5M2Y0MmUwfDFjZTEzM2IyNGQ"]
    
    if let requestId = requestId {
      url = URL(string: "https://api.app.outscraper.com/requests/\(requestId)")!
    } else {
      let fieldList = updateType == "ReviewsData" ? "status,id,name,reviews_data" : "status,id,name,site,street,phone,latitude,longitude,type,working_hours,rating,reviews"   // reservation_links
      url = URL(string: "https://api.app.outscraper.com/maps/reviews-v3?query=\(googlePlaceId)&fields=\(fieldList)&reviewsLimit=5&sort=newest&ignoreEmpty=true")!
    }
    
    do {
      let urlRequest = try URLRequest(url: url, method: .get, headers: headers)
      getData(from: urlRequest) { data, response, error in
        guard let data = data, error == nil else {
          UIImageView.reviewCount += 1
          setMessage("Processed Google \(UIImageView.reviewCount) of \(UIImageView.reviewTotal)")
          return
        }
        do {
          if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let status = json["status"] as? String {
              if status == "Pending" {
                if let id = json["id"] as? String {
                  self.updateGoogleData(googlePlaceId: googlePlaceId, requestId: id, updateType: updateType, documentId: documentId, area: area)
                }
              } else if status == "Success" {
                let db = Firestore.firestore()
                
                if let jsonData = json["data"] as? [[String:Any]], jsonData.count > 0 {
                  var placeName = ""
                  if let name = jsonData[0]["name"] as? String {
                    placeName = name
                  }
                  if updateType == "PlaceData" {
                    var updateWebsite = ""
                    if let website = jsonData[0]["site"] as? String {
                      updateWebsite = website
                    }
                    var updateAddress = ""
                    if let address = jsonData[0]["street"] as? String {
                      updateAddress = address
                    }
                    var updateLocation = GeoPoint(latitude:0,longitude:0)
                    if let latitude = jsonData[0]["latitude"] as? Double, let longitude = jsonData[0]["longitude"] as? Double {
                      updateLocation = GeoPoint(latitude: latitude, longitude: longitude)
                    }
                    var updateDescription = ""
                    if let type = jsonData[0]["type"] as? String {
                      updateDescription = type
                    }
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
                    db.collection("Boston").document(documentId).updateData(["Website":updateWebsite, "Address":updateAddress, "Hours":updateHours, "Description":updateDescription, "Phone":updatePhone, "GoogleRating":updateRating, "GoogleReviews":updateReviews, "Location": updateLocation]) { err in
                      if let err = err {
                          print("Error writing document: \(err)")
                      } else {
                          UIImageView.reviewCount += 1
                          setMessage("Processed Google \(updateType) for \(placeName)")
                          deleteGoogleReviews(googlePlaceId: googlePlaceId)
                          self.updateGoogleData(googlePlaceId: googlePlaceId, requestId: nil, updateType: "ReviewsData", documentId: documentId, area: area)
                      }
                    }
                  } else {
                    if let reviewsData = jsonData[0]["reviews_data"] as? [[String:Any]] {
                      var acceptedReviewCount = 0
                      var minLength = 50
                      var selectedReviews = Dictionary<String, String>()
                      
                      while minLength > 0 {
                        var counter = 0
                        
                        for review in reviewsData {
                          var reviewText = ""
                          if let text = review["review_text"] as? String {
                            reviewText = text
                          }
                          if let ownerAnswer = review["owner_answer"] as? String {
                            reviewText += "<br/><br/><strong>Owner Response</strong><br/><br/>" + ownerAnswer
                          }

                          let reviewLink = review["review_link"] as! String
                          
                          if (reviewText.count > minLength || reviewsData.count < 6) && acceptedReviewCount < 5 && selectedReviews[reviewLink] == nil {
                            acceptedReviewCount += 1
                            let authorImage = review["author_image"] as? String ?? ""
                            let authorName = review["author_title"] as! String
                            let reviewRating = review["review_rating"] as? Double
                            let reviewDate = (review["review_datetime_utc"] as! String).components(separatedBy: " ")[0]
                            let dateFormatter = DateFormatter()
                            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                            dateFormatter.dateFormat = "MM/dd/yyyy"
                            let reviewDateTimestamp = Timestamp(date: dateFormatter.date(from:reviewDate)!)
                            selectedReviews[reviewLink] = reviewLink
                            
                            db.collection("GoogleReview").addDocument(data: [
                              "GooglePlaceId" : googlePlaceId,
                              "AuthorImage" : authorImage,
                              "AuthorName" : authorName,
                              "ReviewDate": reviewDateTimestamp,
                              "ReviewRank" : reviewRating ?? 0.0,
                              "Text" : reviewText,
                              "Link" : reviewLink
                            ]) { err in
                              if let err = err {
                                print("Error adding document: \(err)")
                              }
                            }
                          } else {
                            setMessage("Processed Google \(updateType) for \(placeName)")
                          }
                          
                          counter += 1
                          if counter == 5 {
                            break
                          }
                        }
                        minLength -= 10
                      }
                      if acceptedReviewCount < 6 {
                        setMessage("Processed Google \(updateType) for \(placeName)")
                      }
                    }
                  }
                }
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
  
  func addGoogleReviews(googlePlaceId:String, requestId:String?) {
    var url = URL(string:"about:blank")!
    let headers: HTTPHeaders = ["Content-type": "application/x-www-form-urlencoded", "X-API-KEY": "YXV0aDB8NjQxMDc3ZjRjYjNiYWE4Yjg5M2Y0MmUwfDFjZTEzM2IyNGQ"]
    
    if let requestId = requestId {
      url = URL(string: "https://api.app.outscraper.com/requests/\(requestId)")!
    } else {
      let fieldList = "status,id,name,reviews_data"
      url = URL(string: "https://api.app.outscraper.com/maps/reviews-v3?query=\(googlePlaceId)&fields=\(fieldList)&reviewsLimit=5&sort=newest&ignoreEmpty=true")!
    }
    
    do {
      let urlRequest = try URLRequest(url: url, method: .get, headers: headers)
      getData(from: urlRequest) { data, response, error in
        guard let data = data, error == nil else {
          UIImageView.reviewCount += 1
          setMessage("Processed Google \(UIImageView.reviewCount) of \(UIImageView.reviewTotal)")
          return
        }
        do {
          if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let status = json["status"] as? String {
              if status == "Pending" {
                if let id = json["id"] as? String {
                  self.addGoogleReviews(googlePlaceId: googlePlaceId, requestId: id)
                }
              } else if status == "Success" {
                let db = Firestore.firestore()
                
                if let jsonData = json["data"] as? [[String:Any]], jsonData.count > 0 {
                  if let reviewsData = jsonData[0]["reviews_data"] as? [[String:Any]] {
                    var acceptedReviewCount = 0
                    for review in reviewsData {
                      var reviewText = ""
                      if let text = review["review_text"] as? String {
                        reviewText = text
                      }
                      if let ownerAnswer = review["owner_answer"] as? String {
                        reviewText += "<br/><br/><strong>Owner Response</strong><br/><br/>" + ownerAnswer
                      }
                      if reviewText.count > 20 && acceptedReviewCount < 6 {
                        acceptedReviewCount += 1
                        let authorImage = review["author_image"] as? String ?? ""
                        let authorName = review["author_title"] as! String
                        let reviewRating = review["review_rating"] as! Double
                        let reviewLink = review["review_link"] as! String
                        let reviewDate = (review["review_datetime_utc"] as! String).components(separatedBy: " ")[0]
                        let dateFormatter = DateFormatter()
                        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
                        dateFormatter.dateFormat = "MM/dd/yyyy"
                        let reviewDateTimestamp = Timestamp(date: dateFormatter.date(from:reviewDate)!)
                        
                        db.collection("GoogleReview").addDocument(data: [
                          "GooglePlaceId" : googlePlaceId,
                          "AuthorImage" : authorImage,
                          "AuthorName" : authorName,
                          "ReviewDate": reviewDateTimestamp,
                          "Rating" : reviewRating,
                          "Text" : reviewText,
                          "Link" : reviewLink
                        ]) { err in
                          if let err = err {
                            print("Error adding document: \(err)")
                          }
                        }
                      } else {
                        setMessage("Added Google Reviews")
                      }
                    }
                    if acceptedReviewCount < 6 {
                      setMessage("Done adding Google Reviews")
                    }
                  }
                }
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
  
  func deleteYelpReviews(yelpPlaceId:String) {
    let db = Firestore.firestore()
    db.collection("YelpReview").whereField("YelpPlaceId", isEqualTo: yelpPlaceId).getDocuments { queryReviews, err in
      let reviews = queryReviews!.documents
      for review in reviews {
        let documentId = review.documentID
        db.collection("YelpReview").document(documentId).delete()
      }
    }
  }
  
  func deleteGoogleReviews(googlePlaceId:String) {
    let db = Firestore.firestore()
    db.collection("GoogleReview").whereField("GooglePlaceId", isEqualTo: googlePlaceId).getDocuments { queryReviews, err in
      let reviews = queryReviews!.documents
      for review in reviews {
        let documentId = review.documentID
        db.collection("GoogleReview").document(documentId).delete()
      }
    }
  }
  
  func loadReviews() {
    let db = Firestore.firestore()
    var seconds:Double = 0.0
    let updateType = "PlaceData"
    CoSMap.areaName = reviewArea
    setMessage("Loading Google reviews for \(reviewArea)...")
    CoSMap.placeCounter = 0
    
    db.collection("Boston").whereField("Area", in: [reviewArea]).getDocuments { queryPlaces, err in
      let places = queryPlaces!.documents

      for place in places {
        if let address = place.get("Address") as? String, address == "" {
          deleteGoogleReviews(googlePlaceId: googlePlaceId)
          let documentId = place.documentID
          seconds += 5.0
          if let googlePlaceId = place.get("GooglePlaceId") as? String {
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
              updateGoogleData(googlePlaceId: googlePlaceId, requestId: nil, updateType: updateType, documentId: documentId, area: CoSMap.areaName)
              CoSMap.placeCounter += 1
              print("Google place", CoSMap.placeCounter, places.count)
              //              if CoSMap.placeCounter == places.count {
              self.loadYelpData()
              //              }
            }
          }
        } else {
          CoSMap.placeCounter += 1
          print("Google place (none)", CoSMap.placeCounter, places.count)
        }
      }
    }
  }
  
  func loadYelpData() {
    let db = Firestore.firestore()
    CoSMap.areaName = reviewArea
    CoSMap.placeCounter = 0
    var seconds:Double = 0.0
    setMessage("Loading Yelp data for \(CoSMap.areaName)...")

    db.collection("Boston").whereField("Area", in: [CoSMap.areaName]).getDocuments { queryPlaces, err in
      let places = queryPlaces!.documents

      for place in places {
        if let yelpCategory = place.get("YelpCategory") as? String, yelpCategory == "" {
          let yelpId = place.get("YelpPlaceId") as? String
          let name = place.get("Name") as? String
          if yelpId != nil && yelpId != "" {
            let location = place.get("Location") as! GeoPoint
            let latitude = location.latitude
            let longitude = location.longitude
            CoSMap.yelpPlaceIdToProcess = yelpId!
            seconds += 5.0
            
            DispatchQueue.main.asyncAfter(deadline: .now() + seconds) {
              if let nm = name {
                setMessage("Processing Yelp data for \(nm)...")
              }
              CoSMap.Coordinator.yelpAPIClient.searchBusinesses(byTerm: name!, location: "Hingham, MA", latitude: latitude, longitude: longitude, radius: 1000, categories: nil, locale: nil, limit: 1, offset: nil, sortBy: nil, priceTiers: nil, openNow: nil, openAt: nil, attributes: nil) { business in
                if let business = business {
                  if let businesses = business.businesses {
                    businesses.forEach { businessSearch in
                      let rating = businessSearch.rating
                      let reviews = businessSearch.reviewCount
                      let phone = businessSearch.displayPhone
                      let yelpPrice = businessSearch.price
                      let yelpUrl = businessSearch.url
                      var categoryList = ""
                      if let categories = businessSearch.categories {
                        categories.forEach { category in
                          if categoryList == "" {
                            categoryList = category.title!
                          } else {
                            categoryList += ", " + category.title!
                          }
                        }
                      }
                      let documentId = place.documentID
                      db.collection("Boston").document(documentId).updateData(["YelpReviews":String(reviews!), "YelpRating":rating!, "YelpUrl":(yelpUrl ?? ""), "Phone":(phone ?? ""), "YelpCategory": categoryList, "YelpPrice":(yelpPrice ?? "")])
                      {
                        yelpReview in
                        CoSMap.placeCounter += 1
                        // if CoSMap.placeCounter == places.count {
                          loadYelpReviews()
                        // }
                      }
                    }
                  }
                }
              }
            }
          }
        }
        else
        {
          CoSMap.placeCounter += 1
        }
      }
      yelpPlaceId = ""
    }
  }
  
  func loadYelpReviews() {
    let db = Firestore.firestore()
    CoSMap.areaName = reviewArea
    setMessage("Loading Yelp reviews for \(CoSMap.areaName)...")

    db.collection("Boston").whereField("Area", in: [CoSMap.areaName]).getDocuments { queryPlaces, err in
      let places = queryPlaces!.documents
      
      for place in places {
        if let yelpPlaceId = place.get("YelpPlaceId") as? String, let yelpCategory = place.get("YelpCategory") as? String {
          if yelpPlaceId == CoSMap.yelpPlaceIdToProcess {
            deleteYelpReviews(yelpPlaceId: yelpPlaceId)
            updateYelpReviews(yelpPlaceId: yelpPlaceId, requestId: nil, documentId: place.documentID)
          }
        }
      }
    }
  }
  
  func updateYelpReviews(yelpPlaceId:String, requestId:String?, documentId:String) {
    var url = URL(string:"about:blank")!
    let headers: HTTPHeaders = ["Content-type": "application/x-www-form-urlencoded", "X-API-KEY": "YXV0aDB8NjQxMDc3ZjRjYjNiYWE4Yjg5M2Y0MmUwfDFjZTEzM2IyNGQ"]
    
    if let requestId = requestId {
      url = URL(string: "https://api.app.outscraper.com/requests/\(requestId)")!
    } else {
      let urlString = "https://api.app.outscraper.com/yelp/reviews?query=\(yelpPlaceId)&limit=5&async=false&sort=date_desc"
      url = URL(string: urlString)!
    }
    
    do {
      let urlRequest = try URLRequest(url: url, method: .get, headers: headers)
      getData(from: urlRequest) { data, response, error in
        guard let data = data, error == nil else {
          UIImageView.reviewCount += 1
          setMessage("Processed Yelp Reviews")
          return
        }
        do {
          if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            if let status = json["status"] as? String {
              if status == "Pending" {
                if let id = json["id"] as? String {
                  self.updateYelpReviews(yelpPlaceId: yelpPlaceId, requestId: id, documentId: documentId)
                }
              } else if status == "Success" {
                let db = Firestore.firestore()
                
                if let httpResponse = response as? HTTPURLResponse {
                    print("status \(httpResponse.statusCode)")
                }
                
                db.collection("Boston").whereField("YelpPlaceId", in: [yelpPlaceId]).getDocuments { queryPlaces, err in
                  if queryPlaces != nil {
                    let place = queryPlaces!.documents.first
                    let name = place!.get("Name") as! String
                    setMessage("Processing Yelp reviews for \(name)")
                  }
                }
                
                if let jsonData = json["data"] as? [Any] {
                   let reviewJson = jsonData.first
                   if let reviewJsonArray = reviewJson as? [[String : Any]], reviewJsonArray.count > 0 {
                    for review in reviewJsonArray {
                      if var reviewText = review["review_text"] as? String {
                        if let ownerReplies = review["owner_replies"] as? [String], ownerReplies.count > 0 {
                          reviewText += "<br/><br/><strong>Owner Response</strong><br/><br/>"
                          for reply in ownerReplies {
                            reviewText += reply + "<br/><br/>"
                          }
                        }
                        let authorName = review["author_title"] as! String
                        var authorImage = ""
                        if let reviewPhotos = review["review_photos"] as? [String], reviewPhotos.count > 0 {
                          authorImage = reviewPhotos[0]
                        }
                        let reviewRating = review["review_rating"] as! Double
                        let reviewDate = review["datetime_utc"] as! String
                        let dateFormatter = DateFormatter()
                        dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable US_POSIX
                        dateFormatter.dateFormat = "MM/dd/yyyy HH:mm:ss"
                        let reviewDateTimestamp = Timestamp(date: dateFormatter.date(from:reviewDate)!)

                        db.collection("YelpReview").addDocument(data: [
                          "YelpPlaceId" : yelpPlaceId,
                          "AuthorName" : authorName,
                          "AuthorImage" : authorImage,
                          "ReviewDate": reviewDateTimestamp,
                          "ReviewRank" : reviewRating,
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
                setMessage("Update complete")
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
}

class DataSource: ObservableObject {
  @Published var ready = true
  @Published var level = "area"
  @Published var city = "Boston"
  @Published var center = CLLocationCoordinate2D(latitude: 38.96404, longitude: -77.08884)
  @Published var span = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
  @Published var message = ""
  @Published var filter = ""
  @Published var oldSpecials: [SpecialKey]
  @Published var oldSpecialsString: [String]
  
  init() {
    oldSpecials = []
    oldSpecialsString = []
    
    if let oldSpecialsArray = UserDefaults.standard.stringArray(forKey: "oldSpecials") {
      for oldSpecial in oldSpecialsArray {
        let components = oldSpecial.components(separatedBy: "-")
        let placeName = components[0]
        let startTimestampString = components[1]
        let endTimestampString = components[2]
        let startSeconds = Int64(startTimestampString)!
        let endSeconds = Int64(endTimestampString)!
        let specialKey = SpecialKey(placeName: placeName, startTimestamp: Timestamp(seconds: startSeconds, nanoseconds: 0), endTimestamp: Timestamp(seconds: endSeconds, nanoseconds: 0))
        oldSpecials.append(specialKey)
        oldSpecialsString.append(oldSpecial)
      }
    }
  }
  
  func saveOldSpecials() {
    UserDefaults.standard.set(oldSpecialsString, forKey: "oldSpecials")
  }
  
//  func saveViewedSpecials() {
//    if let encoded = try? JSONEncoder().encode(viewedSpecials) {
//      UserDefaults.standard.set(encoded, forKey: "viewedSpecials")
//      
//      if let data = UserDefaults.standard.data(forKey: "viewedSpecials") {
//        if let decoded = try? JSONDecoder().decode([Special].self, from: data) {
//          var newSpecials = decoded
//        }
//      }
//    }
//  }
}

class LongPressedLocation: Equatable {
  var id = UUID()
  @Published var coordinate = CLLocationCoordinate2D(latitude: 38.96404, longitude: -77.08884)

  init() {
  }
  
  init(coordinate: CLLocationCoordinate2D) {
    self.coordinate = coordinate
  }
  
  static func == (lhs: LongPressedLocation, rhs: LongPressedLocation) -> Bool {
      return lhs.id == rhs.id
  }
}

struct CoSStreetView: UIViewRepresentable {
  public var streetView = GMSPanoramaView(frame: .zero)
  private var _coordinate: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: 42.24238, longitude: -70.88889)
  
  public var coordinate: CLLocationCoordinate2D? {
    set {
      _coordinate = newValue!
      streetView.moveNearCoordinate(newValue!)
    }
    get {
      return _coordinate
    }
  }
  
 // CLLocationCoordinate2D(latitude: -33.732, longitude: 150.312)
  func makeUIView(context: Context) -> GMSPanoramaView {
    streetView.layer.borderWidth = 2.0
    return streetView
  }
  
  func updateUIView(_ view: GMSPanoramaView, context: Context) {
    
  }
}

struct CoSMap: UIViewRepresentable {
  @StateObject var dataSource = DataSource()
  @Binding var longPressedLocation: LongPressedLocation?
  @Binding var showStreetView: Bool
  @Binding public var coordinate: CLLocationCoordinate2D?
  @Binding public var streetView: CoSStreetView
  @Binding public var isHidden: Bool
  public static var mapView = MKMapView()
  public static var activityView:UIView = UIView()
  public static var areaName = ""
  public static var placePoints: [Point] = []
  public static var specialTimers = Dictionary<String, Timer>()
  public static var pointImages = Dictionary<String, UIImage>()
  public static var pointImageOriginalSizes = Dictionary<String, CGSize>()
  public static var placeCounter = 0
  public static var currentImageFolder = "Boston"
  public static var panNumber = 1
  public static var lastDistance = 0.0
  public static var pointToBePlaced: Point?
  public static var annotationsToRemove: [any MKAnnotation] = []
  public static var visibleAnnotations: [MKAnnotation] = []
  public static var lastAreaZoom: Double = 0
  public static var selectedCallout: Callout?
  public static var yelpPlaceIdToProcess = ""
  public static var reviewsDisplayed = false
  
  func makeUIView(context: Context) -> MKMapView {
    let configuration = MKStandardMapConfiguration()
    configuration.pointOfInterestFilter = MKPointOfInterestFilter(including: [.airport, .amusementPark, .evCharger, .fireStation, .library, .nationalPark, .park, .parking, .police, .restroom, .university])
    CoSMap.mapView = MKMapView()
    CoSMap.mapView.delegate = context.coordinator
    CoSMap.mapView.region = MKCoordinateRegion(center: dataSource.center, span: dataSource.span)
    CoSMap.mapView.preferredConfiguration = configuration
    CoSMap.mapView.showsUserLocation = true
    CoSMap.mapView.isZoomEnabled = true
    CoSMap.mapView.isPitchEnabled = false
    CoSMap.mapView.showsCompass = true
    
//    let tgr = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleTap))
//    tgr.numberOfTouchesRequired = 1
//    CoSMap.mapView.addGestureRecognizer(tgr)
    
    let lpgr = UILongPressGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.handleLongPress))
    lpgr.minimumPressDuration = 1
    lpgr.delaysTouchesBegan = true
    CoSMap.mapView.addGestureRecognizer(lpgr)
    
    return CoSMap.mapView
  }
  
  func updateUIView(_ view: MKMapView, context: Context) {
    if context.coordinator.currentCity != dataSource.city {
      context.coordinator.currentCity = dataSource.city
      CoSMap.currentImageFolder = dataSource.city.replacingOccurrences(of: "WashingtonDC", with: "Washington%20DC")
      let db = Firestore.firestore()
      let name = context.coordinator.currentCity.lowercased()
      
//      let location = GeoPoint(latitude:42.35864,longitude:-71.05797)
//      db.collection("Cities").document("Boston").setData(["Center":location, "DisplayName":"Boston", "Heading":0, "Name":"boston", "Tilt":0, "Zoom":14]) { err in
//        if let err = err {
//            print("Error writing document: \(err)")
//        } else {
//            print("set")
//        }
//      }
      
      db.collection("Cities").whereField("Name", in: [name]).getDocuments { queryCities, err in
        if queryCities != nil {
          let city = queryCities!.documents.first
          let center:GeoPoint = city!.get("Center") as! GeoPoint
          self.dataSource.center = CLLocationCoordinate2D(latitude: center.latitude, longitude: center.longitude)
          let zoom = city!.get("Zoom") as? Float ?? 14
          switch zoom {
          case 18:
            self.dataSource.span = MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
          case 16:
            self.dataSource.span = MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
          case 15:
            self.dataSource.span = MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
          case 14:
            self.dataSource.span = MKCoordinateSpan(latitudeDelta: 0.03, longitudeDelta: 0.03)
          case 13:
            self.dataSource.span = MKCoordinateSpan(latitudeDelta: 0.09, longitudeDelta: 0.09)
          case 11:
            if UIDevice.current.userInterfaceIdiom == .pad {
              self.dataSource.span = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            } else {
              self.dataSource.span = MKCoordinateSpan(latitudeDelta: 0.07, longitudeDelta: 0.07)
            }
          default:
            self.dataSource.span = MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
          }
          view.setRegion(MKCoordinateRegion(center: dataSource.center, span: dataSource.span), animated: true)
          context.coordinator.getAreas(view)
        }
      }
    } else if dataSource.level == "area" && context.coordinator.currentLevel == "place" {
      context.coordinator.currentLevel = dataSource.level
      if view.region.span.latitudeDelta < dataSource.span.latitudeDelta + 0.005 {
        context.coordinator.removePlacePoints(view)
        view.setRegion(MKCoordinateRegion(center: dataSource.center, span: dataSource.span), animated: true)
        for image in CoSMap.pointImages {
          if let size = CoSMap.pointImageOriginalSizes[image.key] {
            CoSMap.pointImages[image.key] = image.value.imageScaledToSize(size: size, isOpaque: false)
          }
        }
      }
    } else if dataSource.level == "streetview" {
      showStreetView = false
      dataSource.level = "place"
    }
  }
  
  func makeCoordinator() -> Coordinator {
    Coordinator(self)
  }
  
  public static func startActivityIndicator() {
    CoSMap.activityView = UIView()
    CoSMap.activityView.frame = CGRect(x: 0, y: 0, width: 0, height: 0)
    let activityIndicator = UIActivityIndicatorView(style: .large)
    activityIndicator.color = .black
    activityIndicator.center = CoSMap.mapView.center
    CoSMap.activityView.addSubview(activityIndicator)
    CoSMap.mapView.addSubview(CoSMap.activityView)
    CoSMap.mapView.bringSubviewToFront(CoSMap.activityView)
    activityIndicator.startAnimating()
  }
  
  public static func stopActivityIndicator() {
    _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { timer in
      if CoSMap.activityView.subviews.count > 0 {
        if let activityIndicator = CoSMap.activityView.subviews[0] as? UIActivityIndicatorView {
          activityIndicator.stopAnimating()
          activityIndicator.removeFromSuperview()
          CoSMap.activityView.removeFromSuperview()
          CoSMap.placeCounter = 0
        }
      } else {
        CoSMap.stopActivityIndicator()
      }
    }
  }
  
  public func getPlaces(_ mapView: MKMapView, areaTitle: String, updateAnnotations: Bool) {
    CoSMap.panNumber = 1
    CoSMap.placePoints = []
    CoSMap.placeCounter = 1
    let db = Firestore.firestore()
              
    db.collection(dataSource.city).whereField("Area", in: [CoSMap.areaName]).getDocuments { queryPlaces, err in
      let places = queryPlaces!.documents
      
      for place in places {
        let type = place.get("Type") as? Int ?? 0
        var filter = -1
        if Int(self.dataSource.filter) != nil {
          filter = Int(self.dataSource.filter)!
        }
        if self.dataSource.filter == "" || type == filter {
          let location = place.get("Location") as! GeoPoint
          let mkPointAnnotation = MKPointAnnotation(__coordinate: CLLocationCoordinate2D(latitude: location.latitude, longitude: location.longitude))
          var placePoint = Point(mkPointAnnotation: mkPointAnnotation)
          placePoint.documentId = place.documentID
          if let name = place.get("Name") as? String {
            placePoint.name = name
          }
          placePoint.coordinateLat = location.latitude
          placePoint.coordinateLng = location.longitude
          placePoint.address = place.get("Address") as? String ?? ""
          placePoint.desc = place.get("Description") as? String ?? ""
          placePoint.notes = place.get("Notes") as? String ?? "Notes are coming soon."
          placePoint.type = place.get("Type") as? Int ?? 0
          placePoint.website = place.get("Website") as? String ?? ""
          placePoint.googlePlaceId = place.get("GooglePlaceId") as? String ?? ""
          placePoint.yelpPlaceId = place.get("YelpPlaceId") as? String ?? ""
          placePoint.yelpCategory = place.get("YelpCategory") as? String ?? ""
          placePoint.hours = place.get("Hours") as? String ?? ""
          placePoint.phone = place.get("Phone") as? String ?? ""
          placePoint.price = place.get("YelpPrice") as? String ?? ""
          if let googleRating = place.get("GoogleRating") as? String {
            placePoint.googleRating = Double(googleRating) ?? 0.0
          } else if let googleRating = place.get("GoogleRating") as? Int {
            placePoint.googleRating = Double(googleRating)
          } else if let googleRating = place.get("GoogleRating") as? Double {
            placePoint.googleRating = googleRating
          }
          if let googleReviews = place.get("GoogleReviews") as? String {
            placePoint.googleReviews = Int(googleReviews) ?? 0
          } else if let googleReviews = place.get("GoogleReviews") as? Int {
            placePoint.googleReviews = googleReviews
          }
          if let yelpRating = place.get("YelpRating") as? Double {
            placePoint.yelpRating = yelpRating
          }
          if let yelpReviews = place.get("YelpReviews") as? String {
            placePoint.yelpReviews = Int(yelpReviews) ?? 0
          } else if let yelpReviews = place.get("YelpReviews") as? Int {
            placePoint.yelpReviews = yelpReviews
          }

          CoSMap.placePoints.append(placePoint)
          
          let imageName = CoSMap.currentImageFolder == "Charleston" ? placePoint.address.replacingOccurrences(of: " ", with: "") : Coordinator.sanitizeName(name: placePoint.name)
          CoSMap.pointImages[imageName] = UIImage(named: "\(CoSMap.areaName.replacingOccurrences(of: " ", with: ""))/\(imageName)")
          CoSMap.pointImageOriginalSizes[imageName] = CoSMap.pointImages[imageName]?.size
          if self.dataSource.filter != "" {
            let signName = "\(CoSMap.areaName.replacingOccurrences(of: " ", with: ""))/\(imageName)Sign"
            if let _ = UIImage(named: signName) {
              CoSMap.pointImages["\(imageName)Sign"] = UIImage(named: signName)
            }
          }
        }
      }
      if updateAnnotations == true {
        CoSMap.updatePlaces()
      }
    }
  }
  
  public func updateSpecials() {
    let db = Firestore.firestore()
    
    db.collection("Special").getDocuments { querySpecial, err in
      let specials = querySpecial!.documents
      setupSpecialTimers(specials: specials)
    }
  }
  
  public func setupSpecialTimers(specials:[QueryDocumentSnapshot]) {
    for special in specials {
      if special.get("PlaceName") == nil || special.get("StartTimestamp") == nil || special.get("EndTimestamp") == nil  {
        continue
      }
      let placeName = special.get("PlaceName") as! String
      let startTimestamp = special.get("StartTimestamp") as! Timestamp
      let endTimestamp = special.get("EndTimestamp") as! Timestamp
      
      let oldSpecial = dataSource.oldSpecials.first(where: { special in
        special.placeName == placeName && startTimestamp == special.startTimestamp && endTimestamp == special.endTimestamp
      })

      let special = Special(placeName: placeName, startTimestamp: startTimestamp, endTimestamp: endTimestamp)
      let placePoint = CoSMap.placePoints.first(where: { placePoint in
        placePoint.name == placeName && startTimestamp.dateValue() < Date() && endTimestamp.dateValue() > Date()
      })
      
      if oldSpecial != nil || placePoint == nil || placePoint!.size.height <= 0.0 {
        continue
      }
      
      special.size = placePoint!.size
      var imageName = Coordinator.sanitizeName(name: placePoint!.name)
      imageName = "\(CoSMap.areaName)/\(imageName)"
      
      if let image = UIImage(named: imageName) {
        special.originalImage = image // CIImage(image: image)!
      }
  
      let random = Double.random(in: 0..<6)
      let downLimit = -0.1
      let upLimit = 0.95
      let interval = 0.05
      
      if let placePointIndex = CoSMap.placePoints.firstIndex(of: placePoint!) {
        CoSMap.placePoints[placePointIndex].hasSpecial = true
      }
  
      if CoSMap.specialTimers[placeName] == nil {
        _ = Timer.scheduledTimer(withTimeInterval: random, repeats: false) { timer in
          CoSMap.specialTimers[placeName] = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { timer in
            let image = UIImage.saturateImage(saturationValue: special.pulseCounter, image: special.originalImage, height: placePoint!.size.height)
            placePoint!.placeMarkerAnnotationView.image = image.imageScaledToSize(size: special.size, isOpaque: false)
            
            if special.pulseDirection == "up" {
              special.pulseCounter += 0.05
              if special.pulseCounter > upLimit && special.pulseCounter < upLimit + 0.01 {
                special.pulseDirection = "down"
              }
            } else {
              special.pulseCounter -= 0.05
              if special.pulseCounter < downLimit {
                special.pulseDirection = "up"
              }
            }
          }
        }
      }
    }
  }
  
//  public static func updateGeoLocation(documentId:String, newLocation:CLLocationCoordinate2D) {
//    let db = Firestore.firestore()
//    let geoPoint = GeoPoint(latitude:newLocation.latitude,longitude:newLocation.longitude)
//    db.collection("Boston").document(documentId).updateData(["Location":geoPoint]) { err in
//      if let err = err {
//        print("Error writing document: \(err)")
//      } else {
//        pointToBePlaced!.placeMarkerAnnotationView.isHidden = false
//        pointToBePlaced = nil
//      }
//    }
//  }
  
  public static func updatePlaces() {
//    startActivityIndicator()
    UIImageView.setMapMovementEnabled(enabled: false)
    mapView.removeAnnotations(mapView.annotations)
//    annotationsToRemove = mapView.annotations
  
    CoSMap.specialTimers.forEach { specialTimer in
      specialTimer.value.invalidate()
    }
    
    CoSMap.specialTimers = Dictionary<String, Timer>()
    // let areaZoom = mapView.camera.centerCoordinateDistance / 60
    
    for var placePoint in CoSMap.placePoints {
//      if areaZoom > 7 {
        var title = "" // , emoji = ""
        let desc = placePoint.yelpCategory
        let name = placePoint.name.replacingOccurrences(of: " - Shipyard", with: "")
//        switch desc {
//        case "American":
//        emoji = "🇺🇸"
//        case "Antiques":
//        emoji = "🪑"
//        case "Apartments":
//        emoji = "🏢"
//        case "Art":
//        emoji = "👨🏼‍🎨"
//        case "Bank":
//        emoji = "🏦"
//        case "Barber":
//        emoji = "💈"
//        case "Burgers":
//        emoji = "🍔"
//        case "Cheese":
//        emoji = "🧀"
//        case "Church":
//        emoji = "⛪️"
//        case "Clothing":
//        emoji = "👖"
//        case "Coffee":
//        emoji = "☕️"
//        case "Cosmetics":
//        emoji = "🧴"
//        case "Cycle":
//        emoji = "🚴🏻‍♀️"
//        case "Day care":
//        emoji = "👶"
//        case "Dentist":
//        emoji = "🦷"
//        case "Donuts":
//        emoji = "🍩"
//        case "Dry cleaner":
//        emoji = "🧺"
//        case "Froyo":
//        emoji = "🍦"
//        case "Ferry":
//        emoji = "⛴️"
//        case "Gifts":
//        emoji = "🎁"
//        case "Groceries":
//        emoji = "🍎"
//        case "Gym":
//        emoji = "🏋️‍♀️"
//        case "Home Goods":
//        emoji = "🛋️"
//        case "Ice Cream":
//        emoji = "🍨"
//        case "Italian":
//        emoji = "🇮🇹"
//        case "Jewelry":
//        emoji = "💎"
//        case "Juice":
//        emoji = "🧃"
//        case "Lawyer":
//        emoji = "👩‍💼"
//        case "Liquor":
//        emoji = "🍹"
//        case "Marina":
//        emoji = "⚓️"
//        case "Massage":
//        emoji = "💆🏾"
//        case "Mattresses":
//        emoji = "🛏️"
//        case "Mortgage":
//        emoji = "🏠"
//        case "Movies":
//        emoji = "🎥"
//        case "Museum":
//        emoji = "🏛️"
//        case "Nails":
//        emoji = "💅"
//        case "Nursery":
//        emoji = "🪴"
//        case "Paint":
//        emoji = "🖌️"
//        case "Pets":
//        emoji = "🐈‍⬛"
//        case "Pharmacy":
//        emoji = "💊"
//        case "Photography":
//        emoji = "📸"
//        case "Pizza":
//        emoji = "🍕"
//        case "Post Office":
//        emoji = "📬"
//        case "Pub":
//        emoji = "🍺"
//        case "Real Estate":
//        emoji = "🏘️"
//        case "Salon":
//        emoji = "💇‍♀️"
//        case "Seafood":
//        emoji = "🐟"
//        case "Shoe Repair":
//        emoji = "👞"
//        case "Skin Care":
//        emoji = "💆‍♀️"
//        case "Stationary":
//        emoji = "✉️"
//        case "Thai":
//        emoji = "🪷"
//        case "Townhouses":
//        emoji = "🏫"
//        case "Waxing":
//        emoji = "🦵"
//        case "Wine":
//        emoji = "🍾"
//        case "Women's":
//        emoji = "👚"
//        case "Yoga":
//        emoji = "🧘🏻‍♂️"
//        default:
//        emoji = ""
//        }
        title = name
        //let title
      
        placePoint.annotation = MKPointAnnotation(__coordinate: CLLocationCoordinate2D(latitude: placePoint.coordinate.latitude, longitude: placePoint.coordinate.longitude), title: title, subtitle: desc)
//      } else {
//        placePoint.annotation = MKPointAnnotation(__coordinate: CLLocationCoordinate2D(latitude: placePoint.coordinate.latitude, longitude: placePoint.coordinate.longitude))
//      }
        mapView.addAnnotation(placePoint.annotation)
    }
    
    CoSMap.stopActivityIndicator()
    
//    let area = CoSMap.areaName.replacingOccurrences(of: " ", with: "")
//    var address = "", desc = "", notes = "", website = "", phone = ""
//    var latitude = 0.0, longitude = 0.0
//    CoSMap.pointImages[area] = UIImage(named: "\(area)/\(area)")
    
//    if CoSMap.areaName == "Bethesda Row" {
//      latitude = 38.98151
//      longitude = -77.09678
//      address = "Bethesda/Woodmont/Elm"
//      desc = "Downtown shopping"
//      notes = "<a href='https://www.bethesdarow.com/contact-us/'>Contact Us</a><br/><div style=\"text-align:left;\"><strong>NEIGHBORHOOD ROOTS. GLOBAL SENSIBILITIES.</strong></div>"
//      website = "https://www.bethesdarow.com"
//      phone = "877-265-7417"
//    } else if CoSMap.areaName == "Westbard Square" {
//      latitude = 38.96486
//      longitude = -77.10804
//      address = "Westbard Ave"
//      desc = "Shopping center"
//      notes = "<a href='https://westbardsquare.com/leasing-contacts/'>Contacts</a><br/><br/><div style=\"text-align:left;\"><strong>WHERE IT ALL COMES TOGETHER</strong><br/><br/>The Westwood Shopping Center has been a cornerstone of the Bethesda community for generations. At the new Westbard Square, we’re enhancing everything locals love about this treasured neighborhood staple, creating a dynamic gathering place where shoppers can run a quick errand or stay awhile to catch up with family and friends.<br/><br/>Westbard Square is committed to supporting local retailers while providing a desirable neighborhood destination to satisfy shoppers’ daily needs. The addition of a central green will offer scenic gathering spaces and community-focused activities and amenities.</div>"
//      website = "https://westbardsquare.com"
//      phone = "703-442-4300"
//    } else if CoSMap.areaName == "City Center" {
//      latitude = 38.90201
//      longitude = -77.02559
//      address = "I & 11th St NW"
//      desc = "Shopping destination"
//      notes = ""
//      website = "https://www.citycenterdc.com"
//      phone = "(202) 289-9000"
//    } else if CoSMap.areaName == "Penn Quarter" {
//      latitude = 38.89401
//      longitude = -77.02401
//      address = "Penn Quarter"
//      desc = "Upscale Neighborhood"
//      notes = "Penn Quarter & Chinatown draws foodies, culture vultures, shoppers and sports fans with something to dig into in these neighborhoods north of Pennsylvania Avenue NW, which is as hopping at night as during the day.  Museum fans can wander the Smithsonian Institution’s National Portrait Gallery and American Art Museum (both housed in the same neoclassical building). Nearby, the United States Navy Memorial pays respect to veterans who served in the U.S. Navy with a commemorative public plaza, symbolic statue of a Lone Sailor and the Naval Heritage Center."
//      website = "https://washington.org/dc-neighborhoods/penn-quarter-chinatown"
//      phone = ""
//    } else if CoSMap.areaName == "Chinatown" {
//      latitude = 38.90095
//      longitude = -77.02091
//      address = "Chinatown"
//      desc = "Ethnic neighborhood"
//      notes = ""
//      website = "https://en.wikipedia.org/wiki/Chinatown_(Washington,_D.C.)"
//      phone = ""
//    } else if CoSMap.areaName == "Friendship Heights DC" {
//      latitude = 38.95588
//      longitude = -77.08181
//      address = "NW Washington DC"
//      desc = "Neighborhood"
//      notes = "<div style='text-align:left'><strong>Come meet a friend.</strong><br/><br/>Discover what Friendship Heights has to offer, learn about upcoming activities and the latest neighborhood news, and explore new hidden gems in the neighborhood."
//      website = "https://friendshipheights.com"
//      phone = ""
//    } else if CoSMap.areaName == "Bradley Shopping Center" {
//      latitude = 38.98021
//      longitude = -77.09901
//      address = "6900 Arlington Rd"
//      desc = "Shopping center"
//      notes = "<a href='mail:info@bradleyshoppingcenter.com'>info@bradleyshoppingcenter.com</a><br/><br/><div style=\"text-align:left;\">Come visit our shops at the Bradley Boulevard Shopping Center. We are located at the corner of Arlington Rd. & Bradley Blvd., in Bethesda.</div>"
//      website = "http://bradleyshoppingcenter.com"
//      phone = "(301) 654-5309"
//    } else if CoSMap.areaName == "Friendship Heights" {
//      latitude = 38.96549
//      longitude = -77.08939
//      address = "Village of Friendship Heights, MD"
//      desc = "Residential area"
//      notes = "One of the finest communities in the DMV awaits you at Friendship Heights Village."
//      website = "https://friendshipheightsmd.gov"
//      phone = ""
//    } else if CoSMap.areaName == "Woodmont Triangle" {
//      latitude = 38.990167
//      longitude = -77.099244
//      address = "Bethesda, MD"
//      desc = "Shopping/Residential area"
//      notes = "Woodmont Triangle is a densely urban neighborhood (based on population density) located in Bethesda, Maryland."
//      website = "https://www.neighborhoodscout.com/md/bethesda/woodmont-triangle"
//      phone = ""
//    }

//    if latitude > 0.0 {
//      let mkPointAnnotation = MKPointAnnotation(__coordinate: CLLocationCoordinate2D(latitude: latitude, longitude: longitude))
//      var placePoint = Point(mkPointAnnotation: mkPointAnnotation)
//      placePoint.name = CoSMap.areaName
//      placePoint.coordinateLat = latitude
//      placePoint.coordinateLng = longitude
//      placePoint.address = address
//      placePoint.desc = desc
//      placePoint.notes = notes
//      placePoint.website = website
//      placePoint.phone = phone
//      CoSMap.placePoints.append(placePoint)
//      mapView.addAnnotation(placePoint.annotation)
//    }
    
    UIImageView.setMapMovementEnabled(enabled: true)
  }
  
  public class GestureHandler
  {
    
  }
  
  public class Coordinator: NSObject, MKMapViewDelegate {
    var parent: CoSMap
    var areaZoom: Double = 20
    var areaPoints: [Point] = []
    var loadedAreas = false
    let locationManager = LocationManager()
    var timer = Timer()
    var lastTime = Date()
    var lastSpan = MKCoordinateSpan()
    var gotAreas = false
    var notGoingToArea = true
    let bannerPoints = ["Woodmont Triangle", "Bethesda Row", "Bradley Shopping Center", "Friendship Heights", "Westbard Square", "Sumner Place", "Friendship Heights DC", "City Center", "Penn Quarter", "Chinatown"]
    var authenticated = false
    var currentLevel = "area"
    var currentCity = ""
    var orientationChanged = false
    var pulseTimer = Timer()
    var pulseCounter = 0.2
    var pulseDirection = "up"
    var pulsePlaceMarkerAnnotationView = PlaceMarkerAnnotationView()
    
    public static var yelpAPIClient = CDYelpAPIClient(apiKey: "iQQOaKrSKp4-7jORkK8tYfQiUxHIn78-HefSRafOvFG-AvvoNRwjQhj4_Kb0mqX3IOM__qcUBApaUcTY-YZQLHWY2THQxsiZjKV5zoSD0tcZP5GCCCfFJclGTX33Y3Yx")
    
    init(_ parent: CoSMap) {
      self.parent = parent
    }
    
//    @objc func handleTap(gestureRecognizer: UITapGestureRecognizer) {
//      if let pointToPlace = CoSMap.pointToBePlaced {
//        let location = gestureRecognizer.location(in: CoSMap.mapView)
//        let locationCoordinate = CoSMap.mapView.convert(location, toCoordinateFrom: CoSMap.mapView)
//        CoSMap.updateGeoLocation(documentId: pointToPlace.documentId, newLocation: locationCoordinate)
//      }
//      parent.longPressedLocation = nil
//    }
    
    @objc func handleLongPress(gestureRecognizer: UILongPressGestureRecognizer) {
        if gestureRecognizer.state != UIGestureRecognizer.State.ended {
          return
        } else if gestureRecognizer.state != UIGestureRecognizer.State.began {
          let touchPoint:CGPoint = gestureRecognizer.location(in: CoSMap.mapView)
          let touchMapCoordinates:CLLocationCoordinate2D = CoSMap.mapView.convert(touchPoint, toCoordinateFrom: CoSMap.mapView)
          parent.streetView.coordinate = touchMapCoordinates
          _ = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false) { timer in
            self.parent.showStreetView = true
          }
        }
    }
    
    func mapViewDidFinishLoadingMap(_ mapView: MKMapView) {
      if gotAreas == false {
        gotAreas = true
        if authenticated == false {
          Task {
            do {
              try await Auth.auth().signIn(withEmail: "cconway@cambuilt.com", password: "EujcmJJKSuKQ4Yw")
              authenticated = true
              getAreas(mapView)
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
      NotificationCenter.default.addObserver(self, selector: #selector(self.onOrientationChange), name: UIDevice.orientationDidChangeNotification, object: nil)
    }
    
    @objc func onOrientationChange() {
      self.orientationChanged = true
    }
    
    func onMapCameraChange(frequency: MapCameraUpdateFrequency = .continuous) {
      print("camera changed", frequency)
      
      if CoSMap.lastDistance == 0 {
        CoSMap.lastDistance = CoSMap.mapView.camera.centerCoordinateDistance
      }
      let distance = CoSMap.mapView.camera.centerCoordinateDistance
      print(distance, CoSMap.lastDistance)
    }
    
//    func mapView(_ mapView: MKMapView, regionWillChangeAnimated animated: Bool) {
//      let lat = mapView.camera.centerCoordinate.latitude
//      let lng = mapView.camera.centerCoordinate.longitude
//      var firstTime = false
//      
//      if CoSMap.lastDistance == 0 {
//        firstTime = true
//        CoSMap.lastDistance = mapView.camera.centerCoordinateDistance
//      }
//      let distance = mapView.camera.centerCoordinateDistance
//      let diff = abs(distance - CoSMap.lastDistance)
//      print(diff)
//
//      if diff > 5.0 || firstTime {
//        CoSMap.updatePlaces()
//        CoSMap.lastDistance = distance
//      }
//    }
    
    func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
      if timer.isValid == false && parent.dataSource.level == "place" && self.orientationChanged == false {
//        let lastLatDelta = (self.lastSpan.latitudeDelta * 10000000).rounded()
//        let lastLngDelta = (self.lastSpan.longitudeDelta * 10000000).rounded()
//        let nowLatDelta = (mapView.region.span.latitudeDelta * 10000000).rounded()
//        let nowLngDelta = (mapView.region.span.longitudeDelta * 10000000).rounded()
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { timer in
          if Date().timeIntervalSince(self.lastTime) > 0.1 {
            let delta = mapView.region.span.longitudeDelta
            if (delta < 0.045) && (CoSMap.panNumber != 2 || UIDevice.current.userInterfaceIdiom == .pad) {
              self.notGoingToArea = true
              if abs(CoSMap.lastDistance - CoSMap.mapView.camera.centerCoordinateDistance) > 20 {
                CoSMap.updatePlaces()
                CoSMap.lastDistance = CoSMap.mapView.camera.centerCoordinateDistance
              }
            }
            CoSMap.panNumber = 0
            CoSMap.panNumber += 1
            timer.invalidate()
            self.lastSpan = mapView.region.span
          }
        }
      } else {
        self.orientationChanged = false
        self.orientationChanged = false
        self.lastTime = Date()
        self.lastSpan = mapView.region.span
      }
    }
    
    public func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
      if let titleTry = annotation.title {
        if let title = titleTry, let subtitle = annotation.subtitle, subtitle == "area" {
          let annotationView = AreaMarkerAnnotationView(annotation: annotation, reuseIdentifier: title)
          annotationView.glyphImage = UIImage(systemName: "building.2.fill")
          return annotationView
        } else {
          var distance = 0.0
                   
          let placePoint = placePoints.first { point in
            point.annotation.coordinate.longitude == annotation.coordinate.longitude && point.annotation.coordinate.latitude == annotation.coordinate.latitude
          }!
          
          var newSize = CGSize(), newWidth = 0.0, newHeight = 0.0
          var imageName = Coordinator.sanitizeName(name: currentCity == "Charleston" ? placePoint.address.replacingOccurrences(of: " ", with: "") : placePoint.name)
          let annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: imageName)
          imageName = "\(CoSMap.areaName)/\(imageName)"
          var portraitMultiple:Double = 0
          let screenSizeMultiple = 0.0 // UIScreen.main.bounds.width >= 1024 ? 0.25 : 0
          
//          if parent.dataSource.filter != "" {
//            if let _ = UIImage(named: "\(area)/\(imageName)Sign") {
//              imageName += "Sign"
//            }
//          }
          
          areaZoom = mapView.camera.centerCoordinateDistance / 60
          var delta:Double = 0
          
          if areaZoom > 25 {
            areaZoom = 7.1
          }
          
          if areaZoom > 20 { delta = -10; distance = mapView.camera.centerCoordinateDistance * 0.000002 }
          else if areaZoom > 19 { delta = -15; distance = mapView.camera.centerCoordinateDistance * 0.0000021 }
          else if areaZoom > 18 { delta = -16; distance = mapView.camera.centerCoordinateDistance * 0.0000021 }
          else if areaZoom > 17 { delta = -17; distance = mapView.camera.centerCoordinateDistance * 0.0000022 }
          else if areaZoom > 16 { delta = -18; distance = mapView.camera.centerCoordinateDistance * 0.0000023 }
          else if areaZoom > 15 { delta = -19; distance = mapView.camera.centerCoordinateDistance * 0.0000024 }
          else if areaZoom > 14 { delta = -20; distance = mapView.camera.centerCoordinateDistance * 0.0000025 }
          else if areaZoom > 13 { delta = -30; distance = mapView.camera.centerCoordinateDistance * 0.0000026 }
          else if areaZoom > 12 { delta = -40; distance = mapView.camera.centerCoordinateDistance * 0.0000027 }
          else if areaZoom > 11 { delta = -60; distance = mapView.camera.centerCoordinateDistance * 0.0000028 }
          else if areaZoom > 10 { delta = -80; distance = mapView.camera.centerCoordinateDistance * 0.000003 }
          else if areaZoom > 9 { delta = -100; distance = mapView.camera.centerCoordinateDistance * 0.0000032 }
          else if areaZoom > 8 { delta = -120; distance = mapView.camera.centerCoordinateDistance * 0.0000034 }
          else if areaZoom > 7 { delta = -140; distance = mapView.camera.centerCoordinateDistance * 0.0000036 }
          else if areaZoom > 6 { delta = -160; distance = mapView.camera.centerCoordinateDistance * 0.0000038 }
          else if areaZoom > 5 { delta = -180; distance = mapView.camera.centerCoordinateDistance * 0.0000037 }
          else if areaZoom > 4 { delta = -200; distance = mapView.camera.centerCoordinateDistance * 0.0000037 }
          else if areaZoom > 3 { delta = -220; distance = mapView.camera.centerCoordinateDistance * 0.0000035 }
          else if areaZoom > 2 { delta = -240; distance = mapView.camera.centerCoordinateDistance * 0.000003 }
          else if areaZoom > 1 { delta = -260; distance = mapView.camera.centerCoordinateDistance * 0.000002 }
          else { delta = -300; distance = mapView.camera.centerCoordinateDistance * 0.000002 }
          
          if areaZoom != CoSMap.lastAreaZoom {
//            print("areaZoom is", areaZoom, ", areaZoom was", CoSMap.lastAreaZoom)
            CoSMap.lastAreaZoom = areaZoom
          } else {
//            print("areaZoom same as last:", areaZoom)
          }

          let factor = 6000 + delta
          portraitMultiple = factor - Double(factor * screenSizeMultiple)
          let multiple:Double = portraitMultiple // UIWindow().screen.bounds.width > 820 ? landscapeMultiple : portraitMultiple
          let maxNumber = 2.0 // = area == "WoodmontTriangle" ? 16.0 : area.contains("FriendshipHeights") ? 6.0 : (area == "BradleyShoppingCenter" || area == "Kenwood" || area == "WestbardSquare" || area == "SumnerPlace") ? 7.0 : 14.0
          var placeMarkerAnnotationView = PlaceMarkerAnnotationView()


          CoSMap.placeCounter += 1
          
          if annotationView == nil || placePoint.name == "Chinatown" {
            let divider = max(maxNumber, distance * multiple)
            // print("areaZoom:", areaZoom, " delta:", delta, " divider:", divider)
            placeMarkerAnnotationView = PlaceMarkerAnnotationView(annotation: annotation, reuseIdentifier: imageName)
            placeMarkerAnnotationView.glyphImage = nil
            placeMarkerAnnotationView.glyphTintColor = UIColor.clear
            placeMarkerAnnotationView.markerTintColor = UIColor.clear
            placeMarkerAnnotationView.canShowCallout = true
            placeMarkerAnnotationView.detailCalloutAccessoryView = Callout(placePoint: placePoint, currentImageFolder: CoSMap.currentImageFolder)
            placeMarkerAnnotationView.googlePlaceId = placePoint.googlePlaceId
            
            if !self.bannerPoints.contains(where: { banner in
              banner == placePoint.name
            })
            {
//              print("new view divider", divider)
              if let image = CoSMap.pointImages[imageName] {
                newWidth = image.size.width / divider
                newHeight = image.size.height / divider
                newSize = CGSize(width: newWidth, height: newHeight)
                placeMarkerAnnotationView.image = image.imageScaledToSize(size: newSize, isOpaque: false)
              } else if let image = UIImage(named: imageName) {
                newWidth = image.size.width / divider
                newHeight = image.size.height / divider
                newSize = CGSize(width: newWidth, height: newHeight)
                placeMarkerAnnotationView.image = image.imageScaledToSize(size: newSize, isOpaque: false)
                CoSMap.pointImages[imageName] = image
              }
            } else {
              if let image = UIImage(named: imageName) {
                newWidth = image.size.width / 1.5
                newHeight = image.size.height / 1.5
                newSize = CGSize(width: newWidth, height: newHeight)
                placeMarkerAnnotationView.image = image.imageScaledToSize(size: newSize, isOpaque: false)
              }
            }
          } else {
            let divider = max(maxNumber, distance * multiple)
//            let divider = max(maxNumber, mapView.region.span.longitudeDelta * multiple)
            print("reused view divider", divider)
            placeMarkerAnnotationView = annotationView as! PlaceMarkerAnnotationView
            placeMarkerAnnotationView.annotation = annotation
            placeMarkerAnnotationView.glyphImage = nil
            placeMarkerAnnotationView.glyphTintColor = UIColor.clear
            placeMarkerAnnotationView.markerTintColor = UIColor.clear

            if !self.bannerPoints.contains(where: { banner in
              banner == placePoint.name
            }) {
              if let image = CoSMap.pointImages[imageName] {
                newWidth = image.size.width / divider
                newHeight = image.size.height / divider
                newSize = CGSize(width: newWidth, height: newHeight)
                placeMarkerAnnotationView.image = image.imageScaledToSize(size: newSize, isOpaque: false)
              } else if let image = UIImage(named: imageName) {
                newWidth = image.size.width / divider
                newHeight = image.size.height / divider
                newSize = CGSize(width: newWidth, height: newHeight)
                placeMarkerAnnotationView.image = image.imageScaledToSize(size: newSize, isOpaque: false)
                CoSMap.pointImages[imageName] = image
              }
            } else {
              if let image = UIImage(named: imageName) {
                newWidth = image.size.width / 1.5
                newHeight = image.size.height / 1.5
                newSize = CGSize(width: newWidth, height: newHeight)
                placeMarkerAnnotationView.image = image.imageScaledToSize(size: newSize, isOpaque: false)
              }
            }
          }
          
          if let placePointIndex = placePoints.firstIndex(of: placePoint) {
            placePoints[placePointIndex].size = CGSize(width: newSize.width, height: newSize.height)
            placePoints[placePointIndex].placeMarkerAnnotationView = placeMarkerAnnotationView
          }
          
          return placeMarkerAnnotationView
        }
      } else {
        return nil
      }
    }
    
    func setMessage(_ message:String) {
      DispatchQueue.global().async {
        DispatchQueue.main.async {
          self.parent.dataSource.message = message
        }
      }
    }
    
    func mapView(_ mapView: MKMapView, didSelect view: MKAnnotationView)
    {
      let db = Firestore.firestore()
      
      if let subtitle = view.annotation!.subtitle, subtitle == "area" {
        let displayName = view.annotation!.title!!
        self.removePlacePoints(mapView)
      
        db.collection("\(parent.dataSource.city)Area").whereField("Name", in: [displayName]).getDocuments { queryArea, err in
          for document in queryArea!.documents {
            CoSMap.areaName = document.get("DisplayName") as! String
            let areaCenter = document.get("AreaCenter") as! GeoPoint
            self.areaZoom = document.get("Zoom") as? Double ?? 20
            var delta = 0.002
            var cameraDistance = 700.0
            
            switch self.areaZoom {
            case 10:
              delta = 0.08
              cameraDistance = 17500.0
            case 11:
              delta = 0.07
              cameraDistance = 15000.0
            case 12:
              delta = 0.06
              cameraDistance = 12500.0
            case 13:
              delta = 0.05
              cameraDistance = 10000.0
            case 13.5:
              delta = 0.042
              cameraDistance = 7800.0
            case 14:
              delta = 0.04
              cameraDistance = 7500.0
            case 15:
              delta = 0.03
              cameraDistance = 5000.0
            case 16:
              delta = 0.02
              cameraDistance = 2500.0
            case 17:
              delta = 0.015
            case 17.5:
              delta = 0.008
            case 18:
              delta = 0.01
            case 18.5:
              delta = 0.005
            case 19:
              delta = 0.01
            case 19.5:
              delta = 0.0015
            case 20:
              delta = 0.0005
              cameraDistance = 400.0
            case 21:
              delta = 0.0001
              cameraDistance = 300.0
            default:
              delta = 0.008
            }
            self.notGoingToArea = false
            self.parent.getPlaces(mapView, areaTitle: displayName, updateAnnotations: false)
            let centerCoordinate = CLLocationCoordinate2D(latitude: areaCenter.latitude, longitude: areaCenter.longitude)
            mapView.setRegion(MKCoordinateRegion(center: centerCoordinate, span: MKCoordinateSpan(latitudeDelta: delta, longitudeDelta: delta)), animated: true)

            if let heading = document.get("Heading") as? Double {
              let camera = MKMapCamera()
              camera.heading = heading
              camera.centerCoordinate = centerCoordinate
              camera.centerCoordinateDistance = cameraDistance
              mapView.setCamera(camera, animated: true)
            }
            
            _ = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { timer in
              self.parent.updateSpecials()
            }
          }
          
          self.parent.dataSource.level = "place"
          self.currentLevel = "place"
        }
      } else {
        // ********** Point Placing **************************
//        if let annotation = view.annotation {
//          CoSMap.pointToBePlaced = placePoints.first { point in
//            point.annotation.coordinate.longitude == annotation.coordinate.longitude && point.annotation.coordinate.latitude == annotation.coordinate.latitude
//          }!
//          CoSMap.pointToBePlaced?.placeMarkerAnnotationView.isHidden = true
//        }
        // ********** End Point Placing **********************

        (view.detailCalloutAccessoryView!.superview!.superview!.subviews[2] as! UILabel).text = ""
        (view.detailCalloutAccessoryView!.superview!.superview!.subviews[2] as! UILabel).frame = .zero
        view.detailCalloutAccessoryView!.inputAccessoryViewController?.title = ""
        view.detailCalloutAccessoryView!.superview?.superview?.backgroundColor = .white
        view.detailCalloutAccessoryView!.superview?.superview?.layer.borderWidth = 1.0
        view.detailCalloutAccessoryView!.superview?.superview?.layer.borderColor = .init(red: 0.0, green: 0.0, blue: 0.0, alpha: 0.2)
        
        if let callout = view.detailCalloutAccessoryView as? Callout, let annotation = view.annotation {
          Coordinator.yelpAPIClient.cancelAllPendingAPIRequests()
          callout.loadImageView()
          let placePoint = placePoints.first { point in
            point.annotation.coordinate.longitude == annotation.coordinate.longitude && point.annotation.coordinate.latitude == annotation.coordinate.latitude
          }!
          setupYelpRatings(callout: callout, annotation: annotation, placePoint: placePoint)
          setupGoogleRatings(callout: callout, placePoint: placePoint)
          
          if callout.reviewsBar.subviews.count < 2 {
            callout.reviewsBar.removeFromSuperview()
            callout.notesTextView.topAnchor.constraint(equalTo: callout.imageView.bottomAnchor, constant: 10).isActive = true
          }
          
          if placePoint.hasSpecial == true {
            db.collection("Special").whereField("PlaceName", in: [placePoint.name])
              .whereField("StartTimestamp", isLessThan: Date())
              .whereField("EndTimestamp", isGreaterThan: Date())
              .getDocuments { querySpecial, err in
                
                for document in querySpecial!.documents {
                  let startTimestamp = document.get("StartTimestamp") as! Timestamp
                  let endTimestamp = document.get("EndTimestamp") as! Timestamp
                  let startTimestampSeconds = String(startTimestamp.seconds)
                  let endTimestampSeconds = String(endTimestamp.seconds)
                  let key = "\(placePoint.name)-\(startTimestampSeconds)-\(endTimestampSeconds)"
                  self.parent.dataSource.oldSpecialsString.append(key)
                  self.parent.dataSource.saveOldSpecials()
                }
                
                CoSMap.specialTimers[placePoint.name]?.invalidate()

                let imagePath = "Boston/\(Coordinator.sanitizeName(name: placePoint.name))"
                
                if let image = UIImage(named: imagePath) {
                  placePoint.placeMarkerAnnotationView.image = image.imageScaledToSize(size: placePoint.size, isOpaque: false)
                }
              }
          }
        }
      }
    }
    
    func mapView(_ mapView: MKMapView, didDeselect view: MKAnnotationView) {
      UIImageView.setMapMovementEnabled(enabled: true)
    }
    
    func getData(from url: URLRequest, completion: @escaping (Data?, URLResponse?, Error?) -> ()) {
        URLSession.shared.dataTask(with: url, completionHandler: completion).resume()
    }

    func setupGoogleRatings(callout:Callout, placePoint:Point) {
      if placePoint.googleRating > 0 {
        let googleStarCount = Int(placePoint.googleRating)
        callout.googleRating.html = String(format: "%.1f", placePoint.googleRating)
        if callout.googleRating.html == "0.0" { callout.googleRating.html = "No reviews." }
        let topConstant = -0.5

        if googleStarCount > 0 {
          callout.spacing = 4.0
          callout.reviewsBar.addSubview(callout.googleStar1)
          callout.googleStar1.translatesAutoresizingMaskIntoConstraints = false
          callout.googleStar1.topAnchor.constraint(equalTo: callout.googleRating.topAnchor, constant: topConstant).isActive = true
          callout.googleStar1.leadingAnchor.constraint(equalTo: callout.googleRating.trailingAnchor, constant: callout.spacing).isActive = true
          let googleTapGestureStar1 = UITapGestureRecognizer(target: callout.googleStar1, action: #selector(callout.googleLogo.onGoogleTap(_:)))
          callout.googleStar1.addGestureRecognizer(googleTapGestureStar1)

          callout.spacing += 10
          if googleStarCount > 1 {
            callout.reviewsBar.addSubview(callout.googleStar2)
            callout.googleStar2.translatesAutoresizingMaskIntoConstraints = false
            callout.googleStar2.topAnchor.constraint(equalTo: callout.googleRating.topAnchor, constant: topConstant).isActive = true
            callout.googleStar2.leadingAnchor.constraint(equalTo: callout.googleRating.trailingAnchor, constant: callout.spacing).isActive = true
            callout.spacing += 10
            let googleTapGestureStar2 = UITapGestureRecognizer(target: callout.googleStar2, action: #selector(callout.googleLogo.onGoogleTap(_:)))
            callout.googleStar2.addGestureRecognizer(googleTapGestureStar2)

            if googleStarCount > 2 {
              callout.reviewsBar.addSubview(callout.googleStar3)
              callout.googleStar3.translatesAutoresizingMaskIntoConstraints = false
              callout.googleStar3.topAnchor.constraint(equalTo: callout.googleRating.topAnchor, constant: topConstant).isActive = true
              callout.googleStar3.leadingAnchor.constraint(equalTo: callout.googleRating.trailingAnchor, constant: callout.spacing).isActive = true
              callout.spacing += 10
              let googleTapGestureStar3 = UITapGestureRecognizer(target: callout.googleStar3, action: #selector(callout.googleLogo.onGoogleTap(_:)))
              callout.googleStar3.addGestureRecognizer(googleTapGestureStar3)

              if googleStarCount > 3 {
                callout.reviewsBar.addSubview(callout.googleStar4)
                callout.googleStar4.translatesAutoresizingMaskIntoConstraints = false
                callout.googleStar4.topAnchor.constraint(equalTo: callout.googleRating.topAnchor, constant: topConstant).isActive = true
                callout.googleStar4.leadingAnchor.constraint(equalTo: callout.googleRating.trailingAnchor, constant: callout.spacing).isActive = true
                callout.spacing += 10
                let googleTapGestureStar4 = UITapGestureRecognizer(target: callout.googleStar4, action: #selector(callout.googleLogo.onGoogleTap(_:)))
                callout.googleStar4.addGestureRecognizer(googleTapGestureStar4)

                if googleStarCount > 4 {
                  callout.reviewsBar.addSubview(callout.googleStar5)
                  callout.googleStar5.translatesAutoresizingMaskIntoConstraints = false
                  callout.googleStar5.topAnchor.constraint(equalTo: callout.googleRating.topAnchor, constant: topConstant).isActive = true
                  callout.googleStar5.leadingAnchor.constraint(equalTo: callout.googleRating.trailingAnchor, constant: callout.spacing).isActive = true
                  callout.spacing += 10
                  let googleTapGestureStar5 = UITapGestureRecognizer(target: callout.googleStar5, action: #selector(callout.googleLogo.onGoogleTap(_:)))
                  callout.googleStar5.addGestureRecognizer(googleTapGestureStar5)
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
        if placePoint.googleReviews > 0 {
          callout.googleUserRatingTotal.html = "(\(placePoint.googleReviews))"
        }
        callout.reviewsBar.addSubview(callout.googleUserRatingTotal)
        callout.googleUserRatingTotal.translatesAutoresizingMaskIntoConstraints = false
        callout.googleUserRatingTotal.topAnchor.constraint(equalTo: callout.googleRating.topAnchor, constant: -2.0).isActive = true
        callout.googleUserRatingTotal.leadingAnchor.constraint(equalTo: callout.reviewsBar.leadingAnchor, constant: callout.userRatingTotalConstant).isActive = true
        
        callout.googleLogo.isUserInteractionEnabled = true
        let googleTapGesture = UITapGestureRecognizer(target: callout.googleLogo, action: #selector(callout.googleLogo.onGoogleTap(_:)))
        callout.googleLogo.addGestureRecognizer(googleTapGesture)
      } else {
        callout.googleRating.html = "No reviews."
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
      if callout.yelpRating.html == "0.0" { callout.yelpRating.html = "No reviews." }
      callout.reviewsBar.addSubview(callout.yelpRating)
      callout.yelpRating.translatesAutoresizingMaskIntoConstraints = false
      callout.yelpRating.topAnchor.constraint(equalTo: callout.yelpLogo.topAnchor, constant: 9.0).isActive = true
      callout.yelpRating.leadingAnchor.constraint(equalTo: callout.yelpLogo.trailingAnchor, constant: 3.5).isActive = true
      
      let yelpStarCount = placePoint.yelpRating
      let topConstant = 0.0
      
      if yelpStarCount > 0 {
        callout.spacing = 4.0
        callout.reviewsBar.addSubview(callout.yelpStar1)
        callout.yelpStar1.translatesAutoresizingMaskIntoConstraints = false
        callout.yelpStar1.topAnchor.constraint(equalTo: callout.yelpRating.topAnchor, constant: topConstant).isActive = true
        callout.yelpStar1.leadingAnchor.constraint(equalTo: callout.yelpRating.trailingAnchor, constant: callout.spacing).isActive = true
        let yelpTapGestureStar1 = UITapGestureRecognizer(target: callout.yelpStar1, action: #selector(callout.yelpLogo.onYelpTap(_:)))
        callout.yelpStar1.addGestureRecognizer(yelpTapGestureStar1)
        callout.spacing += 10
        if yelpStarCount > 1 {
          callout.reviewsBar.addSubview(callout.yelpStar2)
          callout.yelpStar2.translatesAutoresizingMaskIntoConstraints = false
          callout.yelpStar2.topAnchor.constraint(equalTo: callout.yelpRating.topAnchor, constant: topConstant).isActive = true
          callout.yelpStar2.leadingAnchor.constraint(equalTo: callout.yelpRating.trailingAnchor, constant: callout.spacing).isActive = true
          let yelpTapGestureStar2 = UITapGestureRecognizer(target: callout.yelpStar2, action: #selector(callout.yelpLogo.onYelpTap(_:)))
          callout.yelpStar2.addGestureRecognizer(yelpTapGestureStar2)
          callout.spacing += 10
          if yelpStarCount > 2 {
            callout.reviewsBar.addSubview(callout.yelpStar3)
            callout.yelpStar3.translatesAutoresizingMaskIntoConstraints = false
            callout.yelpStar3.topAnchor.constraint(equalTo: callout.yelpRating.topAnchor, constant: topConstant).isActive = true
            callout.yelpStar3.leadingAnchor.constraint(equalTo: callout.yelpRating.trailingAnchor, constant: callout.spacing).isActive = true
            let yelpTapGestureStar3 = UITapGestureRecognizer(target: callout.yelpStar3, action: #selector(callout.yelpLogo.onYelpTap(_:)))
            callout.yelpStar3.addGestureRecognizer(yelpTapGestureStar3)
            callout.spacing += 10
            if yelpStarCount > 3 {
              callout.reviewsBar.addSubview(callout.yelpStar4)
              callout.yelpStar4.translatesAutoresizingMaskIntoConstraints = false
              callout.yelpStar4.topAnchor.constraint(equalTo: callout.yelpRating.topAnchor, constant: topConstant).isActive = true
              callout.yelpStar4.leadingAnchor.constraint(equalTo: callout.yelpRating.trailingAnchor, constant: callout.spacing).isActive = true
              let yelpTapGestureStar4 = UITapGestureRecognizer(target: callout.yelpStar4, action: #selector(callout.yelpLogo.onYelpTap(_:)))
              callout.yelpStar1.addGestureRecognizer(yelpTapGestureStar4)
              callout.spacing += 10
              if yelpStarCount > 4 {
                callout.reviewsBar.addSubview(callout.yelpStar5)
                callout.yelpStar5.translatesAutoresizingMaskIntoConstraints = false
                callout.yelpStar5.topAnchor.constraint(equalTo: callout.yelpRating.topAnchor, constant: topConstant).isActive = true
                callout.yelpStar5.leadingAnchor.constraint(equalTo: callout.yelpRating.trailingAnchor, constant: callout.spacing).isActive = true
                let yelpTapGestureStar5 = UITapGestureRecognizer(target: callout.yelpStar5, action: #selector(callout.yelpLogo.onYelpTap(_:)))
                callout.yelpStar5.addGestureRecognizer(yelpTapGestureStar5)
                callout.spacing += 10
              }
            }
          }
        }
      }
      if yelpStarCount < placePoint.yelpRating {
        callout.reviewsBar.addSubview(callout.yelpHalfStar)
        callout.yelpHalfStar.translatesAutoresizingMaskIntoConstraints = false
        callout.yelpHalfStar.topAnchor.constraint(equalTo: callout.yelpRating.topAnchor, constant: topConstant).isActive = true
        callout.yelpHalfStar.leadingAnchor.constraint(equalTo: callout.yelpRating.trailingAnchor, constant: callout.spacing).isActive = true
        let yelpTapGestureHalfStar = UITapGestureRecognizer(target: callout.yelpHalfStar, action: #selector(callout.yelpLogo.onYelpTap(_:)))
        callout.yelpHalfStar.addGestureRecognizer(yelpTapGestureHalfStar)
        callout.spacing += 10
      }
      callout.yelpUserRatingTotal.textFontSize = 11
      callout.yelpUserRatingTotal.textColor = .darkGray
      callout.yelpUserRatingTotal.html = "(\(placePoint.yelpReviews))"
      if callout.yelpUserRatingTotal.html == "(0)" { callout.yelpUserRatingTotal.html = "" }
      callout.reviewsBar.addSubview(callout.yelpUserRatingTotal)
      callout.yelpUserRatingTotal.translatesAutoresizingMaskIntoConstraints = false
      callout.yelpUserRatingTotal.topAnchor.constraint(equalTo: callout.yelpRating.topAnchor, constant: topConstant - 1.0).isActive = true
      callout.yelpUserRatingTotal.leadingAnchor.constraint(equalTo: callout.reviewsBar.leadingAnchor, constant: callout.userRatingTotalConstant).isActive = true

      callout.yelpLogo.isUserInteractionEnabled = true
      let yelpTapGestureLogo = UITapGestureRecognizer(target: callout.yelpLogo, action: #selector(callout.yelpLogo.onYelpTap(_:)))
      callout.yelpLogo.addGestureRecognizer(yelpTapGestureLogo)
    }
    
    func getAreas(_ mapView: MKMapView) {
      let db = Firestore.firestore()
      areaPoints = []
      
      db.collection("\(parent.dataSource.city)Area").getDocuments { queryAreas, err in
        let areas = queryAreas!.documents
        for area in areas {
          let displayName = area.get("DisplayName") as! String
          if !["Penn Quarter", "Chinatown", "City Center"].contains(displayName) {
            let markerLocation = area.get("MarkerLocation") as! GeoPoint
            let areaCenter = area.get("AreaCenter") as! GeoPoint
            let zoom = area.get("Zoom") as? Float ?? 20
            let mkPointAnnotation = MKPointAnnotation(__coordinate: CLLocationCoordinate2D(latitude: markerLocation.latitude, longitude: markerLocation.longitude), title: displayName, subtitle: "area")
            var areaPoint = Point(mkPointAnnotation: mkPointAnnotation)
            areaPoint.displayName = displayName
            areaPoint.coordinateLat = markerLocation.latitude
            areaPoint.coordinateLng = markerLocation.longitude
            areaPoint.name = area.get("Name") as! String
            areaPoint.type = 0
            areaPoint.areaCenterLat = areaCenter.latitude
            areaPoint.areaCenterLng = areaCenter.longitude
            areaPoint.zoom = zoom
            self.areaPoints.append(areaPoint)
            mapView.addAnnotation(mkPointAnnotation)
          }
        }
        self.parent.dataSource.message = ""
      }
    }
    
    func removePlacePoints(_ mapView: MKMapView) {
      let annotationsToRemove = mapView.annotations
      
      for areaPoint in areaPoints {
        let mkPointAnnotation = MKPointAnnotation(__coordinate: CLLocationCoordinate2D(latitude: areaPoint.coordinateLat, longitude: areaPoint.coordinateLng), title: areaPoint.displayName, subtitle: "area")
        mapView.addAnnotation(mkPointAnnotation)
      }
      
      mapView.removeAnnotations(annotationsToRemove)
    }

    static func sanitizeName(name: String) -> String {
      return name.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "&", with: "").replacingOccurrences(of: ".", with: "").replacingOccurrences(of: "'", with: "").replacingOccurrences(of: "-", with: "").replacingOccurrences(of: "/", with: "").replacingOccurrences(of: "é", with: "e").replacingOccurrences(of: "è", with: "e").replacingOccurrences(of: "ã", with: "a").replacingOccurrences(of: "’", with: "").replacingOccurrences(of: ",", with: "")
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
    
    var documentId = ""
    var displayName = ""
    var name = ""
    var address = ""
    var desc = ""
    var notes = ""
    var type = 0
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
    var yelpCategory = ""
    var size = CGSize()
    var placeMarkerAnnotationView = PlaceMarkerAnnotationView()
    var hasSpecial = false
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
    public var closeButton = UIButton(frame: .zero)
    
    init(placePoint: Point, currentImageFolder: String) {
      if UIDevice.current.userInterfaceIdiom == .pad {
        yelpLogo = UIImageView(image: UIImage(named: "YelpiPad"))
        yelpReviewLogo = UIImageView(image: UIImage(named: "YelpiPadReview"))
        googleLogo = UIImageView(image: UIImage(named: "GoogleiPad"))
        googleReviewLogo = UIImageView(image: UIImage(named: "GoogleiPad"))
        googleStar1 = UIImageView(image: UIImage(named: "StariPad"))
        googleStar2 = UIImageView(image: UIImage(named: "StariPad"))
        googleStar3 = UIImageView(image: UIImage(named: "StariPad"))
        googleStar4 = UIImageView(image: UIImage(named: "StariPad"))
        googleStar5 = UIImageView(image: UIImage(named: "StariPad"))
        googleHalfStar = UIImageView(image: UIImage(named: "HalfStariPad"))
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
        googleStar1 = UIImageView(image: UIImage(named: "Star"))
        googleStar2 = UIImageView(image: UIImage(named: "Star"))
        googleStar3 = UIImageView(image: UIImage(named: "Star"))
        googleStar4 = UIImageView(image: UIImage(named: "Star"))
        googleStar5 = UIImageView(image: UIImage(named: "Star"))
        googleHalfStar = UIImageView(image: UIImage(named: "HalfStar"))
        self.yelpStar1 = UIImageView(image: UIImage(named: "Star"))
        self.yelpStar2 = UIImageView(image: UIImage(named: "Star"))
        self.yelpStar3 = UIImageView(image: UIImage(named: "Star"))
        self.yelpStar4 = UIImageView(image: UIImage(named: "Star"))
        self.yelpStar5 = UIImageView(image: UIImage(named: "Star"))
        self.yelpHalfStar = UIImageView(image: UIImage(named: "HalfStar"))
        self.userRatingTotalConstant = 141.0
        self.googleRatingTop = 6.0
        self.hoursLabelTop = -6.0
      }
      
      googleStar1.isUserInteractionEnabled = true
      googleStar2.isUserInteractionEnabled = true
      googleStar3.isUserInteractionEnabled = true
      googleStar4.isUserInteractionEnabled = true
      googleStar5.isUserInteractionEnabled = true
      googleHalfStar.isUserInteractionEnabled = true
      googleRating.isUserInteractionEnabled = true
      googleUserRatingTotal.isUserInteractionEnabled = true

      yelpStar1.isUserInteractionEnabled = true
      yelpStar2.isUserInteractionEnabled = true
      yelpStar3.isUserInteractionEnabled = true
      yelpStar4.isUserInteractionEnabled = true
      yelpStar5.isUserInteractionEnabled = true
      yelpHalfStar.isUserInteractionEnabled = true
      yelpRating.isUserInteractionEnabled = true
      yelpUserRatingTotal.isUserInteractionEnabled = true

      self.placePoint = placePoint
      CoSMap.currentImageFolder = currentImageFolder
      googleReviews = []
      super.init(frame: .zero)
      super.widthAnchor.constraint(equalToConstant: 1210.0).isActive = true
      self.inputViewController?.modalTransitionStyle = .coverVertical
      self.inputViewController?.modalPresentationStyle = .currentContext
      self.inputViewController?.navigationItem.title = ""
      
      setupView()
      isUserInteractionEnabled = true
    }
    
    required init?(coder: NSCoder) {
      fatalError("init(coder:) has not been implemented")
    }
    
    private func setupView() {
      translatesAutoresizingMaskIntoConstraints = false
//      leadingAnchor.constraint(equalTo: leadingAnchor, constant: 100.0).isActive = false
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
      nameLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4.0).isActive = true
      nameLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 4.0).isActive = true
      
      closeButton = UIButton(primaryAction: UIAction(handler: { _ in
        if CoSMap.reviewsDisplayed == true {
          self.reviewListView.isHidden = true
          self.nameLabel.isUserInteractionEnabled = true
          self.phoneTextView.isUserInteractionEnabled = true
          self.notesTextView.isUserInteractionEnabled = true
          UIImageView.setMapMovementEnabled(enabled: true)
          CoSMap.reviewsDisplayed = false
          let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
          self.closeButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: configuration), for: .normal)
        } else {
          CoSMap.mapView.deselectAnnotation(CoSMap.mapView.selectedAnnotations[0], animated: true)
          UIImageView.setMapMovementEnabled(enabled: true)
        }
      }))
      
      addSubview(closeButton)
      
      let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
      closeButton.setImage(UIImage(systemName: "xmark.circle.fill", withConfiguration: configuration), for: .normal)
      closeButton.translatesAutoresizingMaskIntoConstraints = false
      closeButton.tintColor = .black
      closeButton.topAnchor.constraint(equalTo: topAnchor, constant: -11.0).isActive = true
      closeButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 236.0).isActive = true
      closeButton.widthAnchor.constraint(equalToConstant: 32.0).isActive = true
      closeButton.heightAnchor.constraint(equalToConstant: 32.0).isActive = true
    }
    
    private func setupAddress() {
      addressLabel.textFontSize = 11
      addressLabel.textFontWeight = .bold
//      addressLabel.textColor = .gray
      addressLabel.html = placePoint.address
      addSubview(addressLabel)
      addressLabel.translatesAutoresizingMaskIntoConstraints = false
      addressLabel.topAnchor.constraint(equalTo: topAnchor, constant: 10.0).isActive = true
      addressLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4.0).isActive = true
      addressLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: 4.0).isActive = true
      addSubview(phoneTextView)
      phoneTextView.dataDetectorTypes = UIDataDetectorTypes.phoneNumber
      phoneTextView.translatesAutoresizingMaskIntoConstraints = false
      phoneTextView.topAnchor.constraint(equalTo: topAnchor, constant: 25.0).isActive = true
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
      hoursLabel.topAnchor.constraint(equalTo: topAnchor, constant: 50.0).isActive = true
      hoursLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 160.0).isActive = true
      hoursLabel.widthAnchor.constraint(equalToConstant: 90.0).isActive = true
      hoursLabel.textAlignment = .right
      hoursLabel.text = getHoursOpen(hours: placePoint.hours)
    }
    
    private func setupImageView() {
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
    
    public func loadImageView() {
      let imageName = CoSMap.currentImageFolder == "Charleston" ? placePoint.address.replacingOccurrences(of: " ", with: "_") : Coordinator.sanitizeName(name: placePoint.name)
      let imageNumber = CoSMap.currentImageFolder == "Washington%20DC" ? "1" : ""
      let imagePath = "https://res.cloudinary.com/backyardhiddengems-com/image/upload/\(CoSMap.currentImageFolder)/\(imageName)\(imageNumber).png"
      Coordinator.getImageWithURL(urlString: imagePath) { image in
        DispatchQueue.main.async {
          self.imageView.image = image
        }
      }
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
      notesTextView.widthAnchor.constraint(equalToConstant: 270.0).isActive = true
    }

    public func getHoursOpen(hours: String) -> String {
      let daysHours = hours.components(separatedBy: ";")
      
      for dayHours in daysHours {
        let hoursInfo = dayHours.components(separatedBy: ",")
        if hoursInfo[0] == String(Date().dayNumberOfWeek()) {
          return hoursInfo[1]
        }
      }
      
      return ""
    }
    
    public func checkScraperStatus(id:String) {
      let urlStatus = URL(string: "https://api.app.outscraper.com/requests/\(id)")!
      let headers: HTTPHeaders = ["Content-type": "application/x-www-form-urlencoded", "X-API-KEY": "YXV0aDB8NjQxMDc3ZjRjYjNiYWE4Yjg5M2Y0MmUwfDFjZTEzM2IyNGQ"]
      
//      calloutTimer = Timer.scheduledTimer(timeInterval: 0.1, target: self, selector: #selector(checkStatus), userInfo: nil, repeats: true)

      do {
        let urlRequestStatus = try URLRequest(url: urlStatus, method: .get, headers: headers)
        getData(from: urlRequestStatus) { dataStatus, responseStatus, errorStatus in
          guard let dataStatus = dataStatus, errorStatus == nil else { return }
          do {
            if let json = try JSONSerialization.jsonObject(with: dataStatus, options: []) as? [String: Any] {
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
  var type: Int
  
  init(name: String, address: String, desc: String, notes: String, type: Int) {
    self.name = name
    self.address = address
    self.desc = desc
    self.notes = "<div style='font-family: Helvetica, Arial, sans-serif;font-size: 82%;'>\(notes)</div>"
    self.type = type
  }
}

class PlaceMarkerAnnotationView: MKMarkerAnnotationView {
  var placeName = "Joe's Place"
  var placeAddress = "Main St"
  var googlePlaceId = ""
 
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
    super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
  }
  override var annotation: MKAnnotation? {
      willSet {
        titleVisibility = .visible
        displayPriority = .required
      }
  }

}

class AreaMarkerAnnotationView: MKMarkerAnnotationView {
  required init?(coder aDecoder: NSCoder) {
    super.init(coder: aDecoder)
  }
  override init(annotation: MKAnnotation?, reuseIdentifier: String?) {
    super.init(annotation: annotation, reuseIdentifier: reuseIdentifier)
  }
  override var annotation: MKAnnotation? {
      willSet {
          displayPriority = .required
      }
  }
}

class SpecialKey {
  var placeName = ""
  var startTimestamp = Timestamp()
  var endTimestamp = Timestamp()
  
  init (placeName:String, startTimestamp:Timestamp, endTimestamp:Timestamp) {
    self.placeName = placeName
    self.startTimestamp = startTimestamp
    self.endTimestamp = endTimestamp
  }
}

class Special: Identifiable, Codable {
  var id = UUID()
  var placeName = ""
  var startTimestamp = Timestamp()
  var endTimestamp = Timestamp()
  var originalImage = UIImage()
  var size = CGSize()
  var pulseDirection = "up"
  var pulseCounter: Double = 0.0
  
  init() {
    
  }
  
  required init(from decoder: any Decoder) throws {
    
  }
  
  func encode(to encoder: any Encoder) throws {
    
  }
  
  init (placeName: String, startTimestamp: Timestamp, endTimestamp: Timestamp) {
    self.placeName = placeName
    self.startTimestamp = startTimestamp
    self.endTimestamp = endTimestamp
  }
}

//
//  init() {
//    placeName = ""
//    startTimestamp = Timestamp()
//    endTimestamp = Timestamp()
//    placeMarkerAnnotationView = PlaceMarkerAnnotationView()
//    originalImage = CIImage()
//    size = CGSize()
//    pulseDirection = "up"
//    pulseCounter = 0.0
//  }
//}

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
  let reviewRank: Float
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
  
  static func saturateImage(saturationValue : CGFloat, image: UIImage, height:CGFloat) -> UIImage {
    let context = CIContext(options: nil)
    let contrastFilter = CIFilter(name: "CIColorControls")
    let ciImage = CIImage(image: image)
    contrastFilter!.setValue(ciImage, forKey: "inputImage")
    contrastFilter!.setValue(1.0, forKey: "inputContrast")
    let outputContrastImage = contrastFilter!.outputImage!
    
    let redVector = CIVector(x: saturationValue, y: 1, z: 0, w: 0)
    let colorPolynomialFilter = CIFilter(name: "CIColorPolynomial")
    colorPolynomialFilter!.setValue(outputContrastImage, forKey: "inputImage")
    colorPolynomialFilter!.setValue(redVector, forKey: "inputRedCoefficients")
    let outputColorPolynomialImage = colorPolynomialFilter!.outputImage!

    let cgimg = context.createCGImage(outputColorPolynomialImage, from: outputColorPolynomialImage.extent)
    let uiimage = UIImage(cgImage: cgimg!)
    
    return uiimage
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
    CoSMap.mapView.isRotateEnabled = enabled
  }
  
  @objc public func onGoogleTap(_ recognizer: UITapGestureRecognizer) {
    if let callout = recognizer.view?.superview?.superview as? CoSMap.Callout {
      for view in callout.reviewListView.subviews {
        view.removeFromSuperview()
      }

      UIImageView.reviewTop = 13.0
      CoSMap.selectedCallout = callout
      callout.reviewListView.isHidden = false
      callout.reviewListView.layer.zPosition = 1
      callout.closeButton.layer.zPosition = 2
      
      let db = Firestore.firestore()
                
      db.collection("GoogleReview").whereField("GooglePlaceId", in: [callout.placePoint.googlePlaceId]).order(by: "ReviewDate", descending: true).getDocuments { queryReview, err in
        let reviews = queryReview!.documents
        
        if reviews.count == 0 {
          self.noReviewsBar(callout: callout)
        } else {
          UIImageView.setMapMovementEnabled(enabled: false)
          UIImageView.reviewTotal = reviews.count
          UIImageView.reviewCount = 0
          callout.runningReviewHeight = 0.0
          callout.firstReview = true
          let nameLabel = UILabel(frame: .zero)
          callout.reviewListView.addSubview(nameLabel)
          nameLabel.font = UIFont(name: "HelveticaNeue-Bold", size: 12.0)
          nameLabel.textColor = .black
          nameLabel.translatesAutoresizingMaskIntoConstraints = false
          nameLabel.topAnchor.constraint(equalTo: callout.reviewListView.topAnchor, constant: -3.0).isActive = true
          nameLabel.leadingAnchor.constraint(equalTo: callout.reviewListView.leadingAnchor, constant: 10.0).isActive = true
          nameLabel.widthAnchor.constraint(equalToConstant: 260.0).isActive = true
          nameLabel.textAlignment = .left
          nameLabel.text = "                  \(callout.placePoint.name)"
          
          callout.reviewListView.addSubview(callout.googleReviewLogo)
          callout.googleReviewLogo.translatesAutoresizingMaskIntoConstraints = false
          callout.googleReviewLogo.topAnchor.constraint(equalTo: callout.reviewListView.topAnchor, constant: -8.0).isActive = true
          let googleReviewLogoLeadingAnchor = 11.0  // UIDevice.current.userInterfaceIdiom == .pad ? 84.0 : 83.0
          callout.googleReviewLogo.leadingAnchor.constraint(equalTo: callout.reviewListView.leadingAnchor, constant: googleReviewLogoLeadingAnchor).isActive = true
          var reviewCounter = 0
          
          for review in reviews {
//            let documentId = review.documentID
//            db.collection("GoogleReview").document(documentId).delete()

            let authorName = review["AuthorName"] as? String ?? ""
            let reviewDateTimestamp = review["ReviewDate"] as? Timestamp ?? Timestamp()
            let reviewRank = review["ReviewRank"] as? Double ?? 0.0
            let text = review["Text"] as? String ?? ""
            if reviewCounter < 5 {
              if let authorImage = review["AuthorImage"] as? String {
                if let authorImageURL = URL(string: authorImage) {
                  self.getData(from: URLRequest(url: authorImageURL)) { data, response, error in
                    guard let data = data, error == nil else { return }
                    DispatchQueue.main.async() {
                      if let image = UIImage(data: data, scale: 4.0) {
                        self.loadReview(callout: callout, name: authorName, reviewRank: reviewRank, reviewDateTimestamp: reviewDateTimestamp, text: text, image: self.resizeImage(image: image, newWidth: 32.0), source: "Google", reviewCount: reviews.count)
                      } else {
                        self.loadReview(callout: callout, name: authorName, reviewRank: reviewRank, reviewDateTimestamp: reviewDateTimestamp, text: text, image: UIImage(named: "NoAuthorImage") ?? UIImage(), source: "Google", reviewCount: reviews.count)
                      }
                    }
                  }
                }
              } else {
                DispatchQueue.main.async() {
                  self.loadReview(callout: callout, name: authorName, reviewRank: reviewRank, reviewDateTimestamp: reviewDateTimestamp, text: text, image: UIImage(named: "NoAuthorImage") ?? UIImage(), source: "Google", reviewCount: reviews.count)
                }
              }
            }
            reviewCounter += 1
          }
        }
      }
    }
  }
  
  func resizeImage(image: UIImage, newWidth: CGFloat) -> UIImage {
      let scale = newWidth / image.size.width
      let newHeight = image.size.height * scale
      UIGraphicsBeginImageContext(CGSizeMake(newWidth, newHeight))
      image.draw(in: CGRectMake(0, 0, newWidth, newHeight))
      let newImage = UIGraphicsGetImageFromCurrentImageContext()
      UIGraphicsEndImageContext()

      return newImage!
  }
  
  @objc public func onYelpTap(_ recognizer: UITapGestureRecognizer) {
    if let callout = recognizer.view?.superview?.superview as? CoSMap.Callout {
      for view in callout.reviewListView.subviews {
        view.removeFromSuperview()
      }

      UIImageView.reviewTop = 13.0
      callout.reviewListView.isHidden = false
      callout.reviewListView.layer.zPosition = 1
      callout.closeButton.layer.zPosition = 2
      
      let configuration = UIImage.SymbolConfiguration(pointSize: 16, weight: .medium)
      callout.closeButton.setImage(UIImage(systemName: "chevron.backward.circle.fill", withConfiguration: configuration), for: .normal)
      
      // xmark.circle.fill

      let db = Firestore.firestore()
      
      db.collection("YelpReview").whereField("YelpPlaceId", in: [callout.placePoint.yelpPlaceId]).order(by: "ReviewDate", descending: true).getDocuments { queryReview, err in
        let reviews = queryReview!.documents
        if reviews.count == 0 {
          self.noReviewsBar(callout: callout)
        } else {
//          UIImageView.setMapMovementEnabled(enabled: false)
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
          recentLabel.widthAnchor.constraint(equalToConstant: 260.0).isActive = true
          recentLabel.textAlignment = .left
          recentLabel.text = "                 \(callout.placePoint.name)"
          callout.reviewListView.addSubview(callout.yelpReviewLogo)
          callout.yelpReviewLogo.translatesAutoresizingMaskIntoConstraints = false
          callout.yelpReviewLogo.topAnchor.constraint(equalTo: callout.reviewListView.topAnchor, constant: -10.0).isActive = true
          let yelpReviewLogoLeadingAnchor = 11.0  // UIDevice.current.userInterfaceIdiom == .pad ? 85.0 : 83.0
          callout.yelpReviewLogo.leadingAnchor.constraint(equalTo: callout.reviewListView.leadingAnchor, constant: yelpReviewLogoLeadingAnchor).isActive = true
          var reviewCounter = 0
          
          if reviews.count == 0 {
            self.noReviewsBar(callout: callout)
          } else {
            for review in reviews {
              if reviewCounter < 5 {
                var authorName = review["AuthorName"] as? String ?? ""
                authorName = authorName.trimmingCharacters(in: .whitespaces)
                let reviewDateTimestamp = review["ReviewDate"] as! Timestamp
                let reviewRank = review["ReviewRank"] as! Double
                let text = review["Text"] as? String ?? ""
                if let authorImage = review["AuthorImage"] as? String {
                  if authorImage == "" {
                    self.loadReview(callout: callout, name: authorName, reviewRank: reviewRank, reviewDateTimestamp: reviewDateTimestamp, text: text, image: UIImage(named: "NoAuthorImage") ?? UIImage(), source: "Yelp", reviewCount: reviews.count)
                  } else if let authorImageURL = URL(string: authorImage) {
                    self.getData(from: URLRequest(url: authorImageURL)) { data, response, error in
                      guard let data = data, error == nil else { return }
                      DispatchQueue.main.async() {
                        if let image = UIImage(data: data, scale: 32.0) {
                          self.loadReview(callout: callout, name: authorName, reviewRank: reviewRank, reviewDateTimestamp: reviewDateTimestamp, text: text, image: self.resizeImage(image: image, newWidth: 32.0), source: "Yelp", reviewCount: reviews.count)
                        } else {
                          self.loadReview(callout: callout, name: authorName, reviewRank: reviewRank, reviewDateTimestamp: reviewDateTimestamp, text: text, image: UIImage(named: "NoAuthorImage") ?? UIImage(), source: "Yelp", reviewCount: reviews.count)
                        }
                      }
                    }
                  }
                } else {
                  self.loadReview(callout: callout, name: authorName, reviewRank: reviewRank, reviewDateTimestamp: reviewDateTimestamp, text: text, image: UIImage(named: "NoAuthorImage") ?? UIImage(), source: "Yelp", reviewCount: reviews.count)
                }
              }
              reviewCounter += 1
            }
          }
        }
      }
    }
  }
  
  func loadReview(callout:CoSMap.Callout, name:String, reviewRank:Double, reviewDateTimestamp:Timestamp, text:String, image:UIImage, source:String, reviewCount:Int) {
    let dateFormatter = DateFormatter()
    dateFormatter.locale = Locale(identifier: "en_US_POSIX") // set locale to reliable US_POSIX
    dateFormatter.dateFormat = "MM/dd/yyyy"
    let reviewDateString = dateFormatter.string(from: reviewDateTimestamp.dateValue())

    let reviewBar = UIView(frame: .zero)
    CoSMap.reviewsDisplayed = true
    callout.reviewListView.addSubview(reviewBar)
    reviewBar.translatesAutoresizingMaskIntoConstraints = false
    reviewBar.backgroundColor = .white
    reviewBar.topAnchor.constraint(equalTo: callout.reviewListView.topAnchor, constant: UIImageView.reviewTop).isActive = true
    reviewBar.leadingAnchor.constraint(equalTo: callout.reviewListView.leadingAnchor, constant: 0.0).isActive = true
    reviewBar.widthAnchor.constraint(equalTo: callout.reviewListView.widthAnchor).isActive = true
    reviewBar.heightAnchor.constraint(equalToConstant: 40.0).isActive = true
    let indent = 60.0
    let profileImageView = UIImageView(image: image)
    reviewBar.addSubview(profileImageView)
    profileImageView.translatesAutoresizingMaskIntoConstraints = false
    profileImageView.topAnchor.constraint(equalTo: reviewBar.topAnchor, constant: 7.0).isActive = true
    profileImageView.leadingAnchor.constraint(equalTo: reviewBar.leadingAnchor, constant: 19.0).isActive = true
    let author = UILabel(frame: .zero)
    reviewBar.addSubview(author)
    author.font = UIFont.systemFont(ofSize: 12.0, weight: .semibold)
    author.translatesAutoresizingMaskIntoConstraints = false
    author.topAnchor.constraint(equalTo: reviewBar.topAnchor, constant: 10.0).isActive = true
    author.leadingAnchor.constraint(equalTo: reviewBar.leadingAnchor, constant: indent).isActive = true
    author.widthAnchor.constraint(equalToConstant: 200.0).isActive = true
    author.textAlignment = .left
    author.text = name
    UIImageView.reviewTop += 40.0
    UIImageView.reviewCount += 1
    var starCount = Int(reviewRank)
    let starImageName = UIDevice.current.userInterfaceIdiom == .pad ? "StariPad" : "Star"
    let halfStarImageName = UIDevice.current.userInterfaceIdiom == .pad ? "HalfStariPad" : "HalfStar"
    var starLead = indent + 30

    while starCount > 0 {
      let starImageView = UIImageView(image: UIImage(named: starImageName))
      reviewBar.addSubview(starImageView)
      starImageView.translatesAutoresizingMaskIntoConstraints = false
      starImageView.topAnchor.constraint(equalTo: author.bottomAnchor).isActive = true
      starImageView.leadingAnchor.constraint(equalTo: profileImageView.trailingAnchor, constant: starLead).isActive = true
      starLead += 10
      starCount -= 1
    }
    
    if reviewRank > Double(Int(reviewRank)) {
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
    relativeTimeLabel.topAnchor.constraint(equalTo: reviewBar.topAnchor, constant: 25.0).isActive = true
    relativeTimeLabel.leadingAnchor.constraint(equalTo: reviewBar.leadingAnchor, constant: indent).isActive = true
    relativeTimeLabel.widthAnchor.constraint(equalToConstant: 200.0).isActive = true
    relativeTimeLabel.textAlignment = .left
    relativeTimeLabel.text = reviewDateString

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
    reviewTextView.leadingAnchor.constraint(equalTo: reviewBar.leadingAnchor, constant: 17.0).isActive = true
    reviewTextView.topAnchor.constraint(equalTo: reviewBar.bottomAnchor, constant: 5.0).isActive = true
    reviewTextView.backgroundColor = UIColor(red: 0.95, green: 0.95, blue: 0.95, alpha: 1.0)
    reviewTextView.widthAnchor.constraint(equalToConstant: 240.0).isActive = true
    
    if reviewCount == 1 {
      reviewTextView.heightAnchor.constraint(equalToConstant: 66.0 * 8).isActive = true
    } else {
      reviewTextView.heightAnchor.constraint(equalToConstant: 66.0).isActive = true
    }

    UIImageView.reviewTop += 74
    
    if Int(UIImageView.reviewTotal) == UIImageView.reviewCount {
      callout.reviewListView.isHidden = false
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

extension MKMapView {
    func visibleAnnotations() -> [MKAnnotation] {
      return self.annotations(in: self.visibleMapRect).map { obj -> MKAnnotation in return obj as! MKAnnotation }
    }
}
