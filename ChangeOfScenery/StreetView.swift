import UIKit
import GoogleMaps

class StreetView: GMSPanoramaView {
  required init(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override init(frame: CGRect) {
    super.init(frame: frame)
  }
  
  func setLocation(coordinates:CLLocationCoordinate2D) {
//    let panoView = GMSPanoramaView(frame: UIScreen.main.bounds)
//    self.addSubview(panoView)
    moveNearCoordinate(coordinates)
    camera = GMSPanoramaCamera(heading: 180, pitch: -10, zoom: 5)
    print(self.isHidden)
          
    // CLLocationCoordinate2D(latitude: -33.732, longitude: 150.312)
  }
}
                                                                                            
