//
//  PhotoAlbumViewController.swift
//  VirtualTourist
//
//  Created by Ion Ceban on 6/7/21.
//

import Foundation
import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController, NSFetchedResultsControllerDelegate {
    
    
    //MARK: - Outlets
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var flowLayout: UICollectionViewFlowLayout!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!
    @IBOutlet weak var newCollectionViewBtn: UIButton!
    
    //MARK: - Properties
    
    var currentLatitude: Double?
    var currentLongitude: Double?
    var pin: Pin!
    var savedPhotoObjects = [Photo]()
    var flickrPhotos: [FlickrPhoto] = []
    let numbersOfColumns: CGFloat = 3
    var fetchedResultsController: NSFetchedResultsController<Photo>!
    var dictionarySelectedIndexPath: [IndexPath: Bool] = [:]
    
    
    
    //MARK: - LifeCycle Fuctions
    
    override func viewDidLoad() {
        super.viewDidLoad()
        mapView.delegate = self
        collectionView.delegate = self
        collectionView.dataSource = self
        setupBarButtonItems()
        
        //reload saved data
        let savedPhotos = loadSavedData()
        if savedPhotos != nil && savedPhotos?.count != 0 {
            savedPhotoObjects = savedPhotos!
            showSavedResult()
        } else {
            showNewResult()
        }
        setCenter()
        activityIndicator.startAnimating()
    }
    
    
    
    //MARK: - Fetch Core Data
    fileprivate func loadSavedData() -> [Photo]? {
        var photoArray: [Photo] = []
            let fetchRequest: NSFetchRequest<Photo> = Photo.fetchRequest()
            let predicate = NSPredicate(format: "pin == %@", argumentArray: [pin!])
            fetchRequest.predicate = predicate
            let sortDescriptor = NSSortDescriptor(key: "imageURL", ascending: true)
            fetchRequest.sortDescriptors = [sortDescriptor]
            
            
        fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest, managedObjectContext: DataController.shared.viewContext, sectionNameKeyPath: nil, cacheName: nil)
            fetchedResultsController.delegate = self
        
        do {
            try fetchedResultsController.performFetch()
            let photoCount = try fetchedResultsController.managedObjectContext.count(for: fetchedResultsController.fetchRequest)
            
            for index in 0..<photoCount {
                
                photoArray.append(fetchedResultsController.object(at: IndexPath(row: index, section: 0)))
            }
            return photoArray
            
        } catch {
            print("error performing fetch")
            return nil
        }
    }
  
    
    //MARK: - Methods
    
    
    // Make a call to FlikrClient
    func getFlickrPhoto() {
        
        FlickrClient.shared.getFlickrPhotos(lat: currentLatitude!, lon: currentLongitude!, page: 1, completion: { (photos, error) in
            if let error = error {
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.showAlertMessage()
                    print(error.localizedDescription)
                }
            } else {
                if let photos = photos {
                    
                    DispatchQueue.main.async {
                        self.flickrPhotos = photos
                        self.savePhotoToCoreData(photos: photos)
                        self.activityIndicator.stopAnimating()
                        self.collectionView.reloadData()
                        self.savedPhotoObjects = self.loadSavedData()!
                        self.showSavedResult()
                    }
                }
            }
        })
    }
    
    fileprivate func getRandomImages() {
        let random = Int.random(in: 2...4)
        FlickrClient.shared.getFlickrPhotos(lat: currentLatitude!, lon: currentLongitude!, page: random, completion: { photos, error in
                
            if let error = error {
                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.showAlertMessage()
                    print(error.localizedDescription)
                }
            } else {
                if let photos = photos {
                    
                    DispatchQueue.main.async {
                        self.flickrPhotos = photos
                        self.savePhotoToCoreData(photos: photos)
                        self.activityIndicator.stopAnimating()
                        self.savedPhotoObjects = self.loadSavedData()!
                        self.showSavedResult()
                    }
                }
            }
            
        })
    }
    
    // Save photos to coreData
    func savePhotoToCoreData(photos: [FlickrPhoto]) {
        for flickrPhoto in photos {
            let photo = Photo(context: DataController.shared.viewContext)
            photo.imageURL = flickrPhoto.imageURLString()
            photo.pin = pin
            savedPhotoObjects.append(photo)
            DataController.shared.save()
        }
    }
    
    func deleteExistingCoreDataPhoto() {
        for image in savedPhotoObjects {
            DataController.shared.viewContext.delete(image)
        }
    }
    
    func showNewResult() {
        deleteExistingCoreDataPhoto()
        savedPhotoObjects.removeAll()
        getFlickrPhoto()
    }
    
    func showSavedResult() {
        DispatchQueue.main.async {
            self.collectionView.reloadData()
        }
    }
    
    //MARK: - UICollectionView: Select Multiple items & delete UICollectionViewCell
    
    // Define enum points
    enum Mode {
        case view
        case select
    }
    
    
    //Switch selected button on selection
    var mMode: Mode = .view {
        didSet {
            switch mMode {
            case.view:
                for (key, value) in dictionarySelectedIndexPath {
                    if value {
                        collectionView.deselectItem(at: key, animated: true)
                    }
                }
                
                dictionarySelectedIndexPath.removeAll()
                
                selectBarButton.title = "Select"
                navigationItem.leftBarButtonItem = nil
                collectionView.allowsMultipleSelection = false
            case.select:
                selectBarButton.title = "Cancel"
                navigationItem.leftBarButtonItem = deleteBarButton
                collectionView.allowsMultipleSelection = true
            }
        }
    }
    
    // Create UIBarButtons
    
    //Created select buttonItem
    lazy var selectBarButton: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(title: "Select", style: .plain, target: self, action: #selector(didSelectButtonClicked(_:)))
        return barButtonItem
    }()
    
    //Created delete buttonItem
    lazy var deleteBarButton: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(didDeletButtonClicked(_:)))
        return barButtonItem
    }()
    
    
    // Methods select & delete button clicked
    
    @objc func didSelectButtonClicked(_ sender: UIBarButtonItem) {
        mMode =  mMode == .view ? .select : .view
    }
    
    @objc func didDeletButtonClicked(_ sender: UIBarButtonItem) {
        if let selectedIndexPaths = collectionView.indexPathsForSelectedItems {
            for indexPath in selectedIndexPaths {
                let savedPhoto = savedPhotoObjects[indexPath.row]
                for photo in savedPhotoObjects {
                    if photo.imageURL == savedPhoto.imageURL {
                        DataController.shared.viewContext.delete(photo)
                       try? DataController.shared.viewContext.save()
                    }
                }
            }
            savedPhotoObjects = loadSavedData()!
            showSavedResult()
    
        }
    }
    
    // Setup bar buttonItem method
    private func setupBarButtonItems() {
        navigationItem.rightBarButtonItem = selectBarButton
        
    }

    //MARK: - Action Buttons
    
    @IBAction func newCollectionButtonPressed(_ sender: Any) {
        activityIndicator.startAnimating()
        deleteExistingCoreDataPhoto()
        getRandomImages()
        activityIndicator.stopAnimating()
    }
    
}

//MARK: - Set up MapView Delegate

extension PhotoAlbumViewController: MKMapViewDelegate {
    
    func setCenter() {
        if let latitude = currentLatitude,
            let longitude = currentLongitude {
        let center: CLLocationCoordinate2D = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            mapView.setCenter(center, animated: true)
            let mySpan: MKCoordinateSpan = MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            let myRegion: MKCoordinateRegion = MKCoordinateRegion(center: center, span: mySpan)
            mapView.setRegion(myRegion, animated: true)
            let annotation: MKPointAnnotation = MKPointAnnotation()
            annotation.coordinate = center
            mapView.addAnnotation(annotation)
        }
    }
}


//MARK: - Set up Collcetion View Delegates

extension PhotoAlbumViewController: UICollectionViewDelegateFlowLayout, UICollectionViewDataSource {
    
    func numberOfSections(in collectionView: UICollectionView) -> Int {
        return 1
    }
    

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return savedPhotoObjects.count
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "FlickrViewCell", for: indexPath) as! FlickrViewCell
        
        let photoObject = savedPhotoObjects[indexPath.row]
        activityIndicator.stopAnimating()
        cell.photoImage.image = UIImage(named: "placeholder-image")
        cell.initWithPhoto(photoObject)
       
       
    return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        let width = collectionView.frame.width / numbersOfColumns
        return CGSize(width: width, height: width)
    }
   
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, insetForSectionAt section: Int) -> UIEdgeInsets {
        return .zero
       }
 
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumLineSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, minimumInteritemSpacingForSectionAt section: Int) -> CGFloat {
        return 0
    }
 
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        switch mMode {
        case .view:
          collectionView.deselectItem(at: indexPath, animated: true)
            _ = collectionView.cellForItem(at: indexPath)
        case .select:
          dictionarySelectedIndexPath[indexPath] = true
        }
       
    }
    
    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        if mMode == .select {
          dictionarySelectedIndexPath[indexPath] = false
        
        }
       
    }
    
}

//MARK: - Alert Message Method

extension PhotoAlbumViewController {
    // Alert  message method
    func showAlertMessage() {
        let alertVc = UIAlertController(title: "Error", message: "Error retrieving data", preferredStyle: .alert)
        alertVc.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        self.present(alertVc, animated: true)
    }
}

