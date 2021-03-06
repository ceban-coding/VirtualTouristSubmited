//
//  FlickrViewCell.swift
//  VirtualTourist
//
//  Created by Ion Ceban on 6/21/21.
//

import UIKit

class FlickrViewCell: UICollectionViewCell {
    
    //MARK: - Outles
    @IBOutlet weak var photoImage: UIImageView!
    @IBOutlet weak var highlightIndicator: UIImageView!
    @IBOutlet weak var selectIndicator: UIImageView!
    
    //MARK: - Set highlited and selected indicator
    
    // Highlited indicator
    override var isHighlighted: Bool {
        didSet {
            highlightIndicator.isHidden = !isHighlighted
        }
    }
    
    override var isSelected: Bool {
        didSet {
            highlightIndicator.isHidden = !isSelected
            selectIndicator.isHidden = !isSelected
            
        }
    }
    
    
    

    //Initiate photo
    func initWithPhoto(_ photo: Photo) {
        if photo.imageData != nil {
            DispatchQueue.main.async {
                self.photoImage.image = UIImage(data: photo.imageData! as Data)
            }
        } else {
            downloadImage(photo)
        }
    }
    
    //Download Images
    func downloadImage(_ photo: Photo) {
        URLSession.shared.dataTask(with: URL(string: photo.imageURL!)!) { (data, response, error) in
            if error == nil {
                DispatchQueue.main.async {
                    self.photoImage.image = UIImage(data: data! as Data)
                }
            }
        }
        .resume()
    }

    //Save Image to core data
    func saveImageDataToCoreData(_ photo: Photo, imageData: Data) {
        do {
            photo.imageData = imageData
            try DataController.shared.viewContext.save()
        } catch {
            print("saving photo image failed")
        }
    }
}
