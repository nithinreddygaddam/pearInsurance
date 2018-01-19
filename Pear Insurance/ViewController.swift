//
//  ViewController.swift
//  Pear Insurance
//
//  Created by Nithin Reddy Gaddam on 1/16/18.
//  Copyright © 2018 Pear Insurance. All rights reserved.
//

import UIKit
import GoogleMaps
import GooglePlaces
import SwiftyJSON
import Alamofire

enum Location {
    case startLocation
    case destinationLocation
}

class ViewController: UIViewController, CLLocationManagerDelegate, GMSMapViewDelegate {

    @IBOutlet weak var rideButton: UIButton!
    @IBOutlet weak var rideView: UIView!
    @IBOutlet weak var rideCardNumberLabel: UILabel!
    @IBOutlet weak var estimateCostLabel: UILabel!
    @IBOutlet weak var estimateMileageLabel: UILabel!
    @IBOutlet weak var estimateSurgeLabel: UILabel!
    @IBOutlet weak var estimateDistanceLabel: UILabel!
    @IBOutlet weak var rideCoverageLabel: UILabel!
    @IBOutlet weak var estimatesView: UIView!
    @IBOutlet weak var destinationView: UIView!
    @IBOutlet weak var currentAddressText: UITextField!
    @IBOutlet weak var destinationAddressText: UITextField!
    @IBOutlet weak var rideStatsLabel: UILabel!
    @IBOutlet weak var rideSummaryView: UIView!
    @IBOutlet weak var summaryMilesLabel: UILabel!
    @IBOutlet weak var summaryMileageLabel: UILabel!
    @IBOutlet weak var summaryCostLabel: UILabel!
    @IBOutlet weak var mapView: GMSMapView!

    let locationManager = CLLocationManager()
    var currentAddressFlag = false
    var currentAddress: GMSPlace?
    var destinationAdress: GMSPlace?
    var timer = Timer()
    var placesClient: GMSPlacesClient!
    var estimateRate = 2.347
    var averageCost = 2.138
    var congestionSurge = 11.2
    var distance = 0.0 {
        didSet {
            self.estimateDistanceLabel.text = "\(distance) miles"
            self.summaryMilesLabel.text = "\(distance) miles"
            self.estimatesView.isHidden = false
            estimateRideCost()
        }
    }


    // An array to hold the list of likely places.
    var likelyPlaces: [GMSPlace] = []

    // The currently selected place.
    var selectedPlace: GMSPlace?

    override func viewDidLoad() {
        super.viewDidLoad()

        // Ask for Authorisation from the User.
        self.locationManager.requestAlwaysAuthorization()

        // For use in foreground
        self.locationManager.requestWhenInUseAuthorization()

        if CLLocationManager.locationServicesEnabled() {
            startUpdatingLocation()
        }

        self.becomeFirstResponder()
    }

    override var canBecomeFirstResponder: Bool {
        get {
            return true
        }
    }

    // Enable detection of shake motion
    override func motionEnded(_ motion: UIEventSubtype, with event: UIEvent?) {
        if motion == .motionShake {
            let storyboard = UIStoryboard(name: "Main", bundle: nil)
            let buckleViewController = storyboard.instantiateViewController(withIdentifier: "BuckleUpViewController")
            buckleViewController.modalPresentationStyle = .overCurrentContext
            self.present(buckleViewController, animated: true, completion: nil)
        }
    }

    fileprivate func startUpdatingLocation() {
        self.locationManager.delegate = self
        self.locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        self.locationManager.startUpdatingLocation()
        self.locationManager.distanceFilter = 50
        placesClient = GMSPlacesClient.shared()
        runTimer()
    }

    @objc fileprivate func stopUpdatingLocation() {
        locationManager.stopUpdatingLocation()
        if likelyPlaces.count > 0 {
            self.currentAddress = likelyPlaces[0]
            guard let addressArray = self.currentAddress?.formattedAddress?.components(separatedBy: ",") else {
                return
            }
            if addressArray.count > 2 {
                self.currentAddressText.text = "\(addressArray[0]),\(addressArray[1]),\(addressArray[2])"
            } else {
                self.currentAddressText.text = self.currentAddress?.formattedAddress
            }
        }
    }

    func runTimer() {
        timer = Timer.scheduledTimer(timeInterval: 2, target: self,   selector: (#selector(ViewController.stopUpdatingLocation)), userInfo: nil, repeats: false)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        let currentLocation:CLLocationCoordinate2D = manager.location!.coordinate
        print("locations = \(currentLocation.latitude) \(currentLocation.longitude)")
        let camera = GMSCameraPosition.camera(withLatitude: currentLocation.latitude, longitude: currentLocation.longitude, zoom: 15)

        self.mapView.camera = camera
        self.mapView.delegate = self
        self.mapView.animate(to: camera)
        self.mapView?.isMyLocationEnabled = true
        self.mapView.settings.compassButton = true
        self.mapView.settings.zoomGestures = true
        self.mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]

        listLikelyPlaces()
    }

    // Handle authorization for the location manager.
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .restricted:
            print("Location access was restricted.")
        case .denied:
            print("User denied access to location.")
            // Display the map using the default location.
            mapView?.isHidden = false
        case .notDetermined:
            print("Location status not determined.")
        case .authorizedAlways: fallthrough
        case .authorizedWhenInUse:
            print("Location status is OK.")
            startUpdatingLocation()
        }
    }

    // Handle location manager errors.
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        locationManager.stopUpdatingLocation()
        print("Error: \(error)")
    }

    // Populate the array with the list of likely places.
    func listLikelyPlaces() {
        // Clean up from previous sessions.
        likelyPlaces.removeAll()

        placesClient.currentPlace(callback: { (placeLikelihoods, error) -> Void in
            if let error = error {
                // TODO: Handle the error.
                print("Current Place error: \(error.localizedDescription)")
                return
            }

            // Get likely places and add to the list.
            if let likelihoodList = placeLikelihoods {
                for likelihood in likelihoodList.likelihoods {
                    let place = likelihood.place
                    self.likelyPlaces.append(place)
                }
            }
        })
    }

    @IBAction func onInsureButtonPressed(_ sender: Any) {
        self.destinationAddressText.text = ""
        destinationAdress = nil
        self.estimatesView.isHidden = true
        self.rideView.isHidden = true
        self.rideStatsLabel.isHidden = false
        self.rideSummaryView.isHidden = false
        calculateRideCost()
    }

    @IBAction func onDoneRideButtonPressed(_ sender: Any) {
        self.rideButton.isEnabled = false
        self.rideView.isHidden = false
        self.rideStatsLabel.isHidden = true
        self.rideSummaryView.isHidden = true
    }

    @IBAction func onCurrentAddressPressed(_ sender: Any) {
        let autocompleteController = GMSAutocompleteViewController()
        autocompleteController.delegate = self
        currentAddressFlag = true
        present(autocompleteController, animated: true, completion:nil)
    }

    @IBAction func onDestinationAddressPressed(_ sender: Any) {
        let autocompleteController = GMSAutocompleteViewController()
        currentAddressFlag = false
        autocompleteController.delegate = self
        present(autocompleteController, animated: true, completion: nil)
    }

    fileprivate func calculateRideCost() {
        self.summaryCostLabel.text = "$\((averageCost * distance)/100 * (1 + (congestionSurge/100)))"
    }

    fileprivate func destinationAddressUpdated() {
        // Creates a marker in the center of the map.
        guard let destinationAddress = destinationAdress, let currentAddress = currentAddress else {
            return
        }
        // Clear the previous route
        self.mapView.clear()

        self.createMarker(titleMarker: destinationAddress.name, latitude: destinationAddress.coordinate.latitude, longitude: destinationAddress.coordinate.longitude)
        let start = CLLocation(latitude: currentAddress.coordinate.latitude, longitude: currentAddress.coordinate.longitude)
        let end = CLLocation(latitude: destinationAddress.coordinate.latitude, longitude: destinationAddress.coordinate.longitude)
        self.drawPath(startLocation: start, endLocation: end)

        guard let addressArray = destinationAddress.formattedAddress?.components(separatedBy: ",") else {
            return
        }
        if addressArray.count > 2 {
            self.destinationAddressText.text = "\(addressArray[0]),\(addressArray[1]),\(addressArray[2])"
        } else {
            self.destinationAddressText.text = self.currentAddress?.formattedAddress
        }

        let bounds = GMSCoordinateBounds(coordinate: destinationAddress.coordinate, coordinate: currentAddress.coordinate)
        let camera = mapView.camera(for: bounds, insets: UIEdgeInsets())!
        self.mapView.camera = camera

        self.rideButton.isEnabled = true

    }

    fileprivate func estimateRideCost() {
        self.estimateCostLabel.text = "$\(((averageCost * distance)/100) * (1 + (congestionSurge/100)) )"
    }

    func lookUpCurrentLocation(completionHandler: @escaping (CLPlacemark?)
        -> Void ) {
        // Use the last reported location.
        if let lastLocation = self.locationManager.location {
            let geocoder = CLGeocoder()

            // Look up the location and pass it to the completion handler
            geocoder.reverseGeocodeLocation(lastLocation,
                                            completionHandler: { (placemarks, error) in
                                                if error == nil {
                                                    let firstLocation = placemarks?[0]
                                                    completionHandler(firstLocation)
                                                }
                                                else {
                                                    // An error occurred during geocoding.
                                                    completionHandler(nil)
                                                }
            })
        }
        else {
            // No location was available.
            completionHandler(nil)
        }
    }

    // MARK: function for create a marker pin on map
    func createMarker(titleMarker: String, latitude: CLLocationDegrees, longitude: CLLocationDegrees) {
        let marker = GMSMarker()
        marker.position = CLLocationCoordinate2DMake(latitude, longitude)
        marker.title = titleMarker
        marker.map = mapView
    }

    //MARK: - this is function for create direction path, from start location to desination location
    func drawPath(startLocation: CLLocation, endLocation: CLLocation)
    {

        let origin = "\(startLocation.coordinate.latitude),\(startLocation.coordinate.longitude)"
        let destination = "\(endLocation.coordinate.latitude),\(endLocation.coordinate.longitude)"

        let url = "https://maps.googleapis.com/maps/api/directions/json?origin=\(origin)&destination=\(destination)&mode=driving"

        Alamofire.request(url).responseJSON { response in

            print(response.request as Any)  // original URL request
            print(response.response as Any) // HTTP URL response
            print(response.data as Any)     // server data
            print(response.result as Any)   // result of response serialization

            let json = JSON(data: response.data!)
            let routes = json["routes"].arrayValue
            
            if let distanceArray = json["routes"][0]["legs"][0]["distance"]["text"].string?.components(separatedBy: " "){
                self.distance = Double(distanceArray[0])!
            }

            // print route using Polyline
            for route in routes
            {
                let routeOverviewPolyline = route["overview_polyline"].dictionary
                let points = routeOverviewPolyline?["points"]?.stringValue
                let path = GMSPath.init(fromEncodedPath: points!)
                let polyline = GMSPolyline.init(path: path)
                polyline.strokeWidth = 6
                polyline.strokeColor = UIColor.red
                polyline.map = self.mapView
            }
        }
    }
}

extension ViewController: GMSAutocompleteViewControllerDelegate {

    // Handle the user's selection.
    func viewController(_ viewController: GMSAutocompleteViewController, didAutocompleteWith place: GMSPlace) {
        print("Place name: \(place.name)")
        print("Place address: \(String(describing: place.formattedAddress))")
        dismiss(animated: true, completion: {
            if self.currentAddressFlag {
                self.currentAddressText.text = place.name
                self.currentAddress = place
            } else {
                self.destinationAddressText.text = place.name
                self.destinationAdress = place
                self.destinationAddressUpdated()
            }
        })
    }

    func viewController(_ viewController: GMSAutocompleteViewController, didFailAutocompleteWithError error: Error) {
        // TODO: handle the error.
        print("Error: ", error.localizedDescription)
    }

    // User canceled the operation.
    func wasCancelled(_ viewController: GMSAutocompleteViewController) {
        dismiss(animated: true, completion: nil)
    }

    // Turn the network activity indicator on and off again.
    func didRequestAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }

    func didUpdateAutocompletePredictions(_ viewController: GMSAutocompleteViewController) {
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }

}
