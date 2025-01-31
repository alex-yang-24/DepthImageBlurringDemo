/// Copyright (c) 2020 Razeware LLC
///
/// Permission is hereby granted, free of charge, to any person obtaining a copy
/// of this software and associated documentation files (the "Software"), to deal
/// in the Software without restriction, including without limitation the rights
/// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
/// copies of the Software, and to permit persons to whom the Software is
/// furnished to do so, subject to the following conditions:
///
/// The above copyright notice and this permission notice shall be included in
/// all copies or substantial portions of the Software.
///
/// Notwithstanding the foregoing, you may not use, copy, modify, merge, publish,
/// distribute, sublicense, create a derivative work, and/or sell copies of the
/// Software in any work that is designed, intended, or marketed for pedagogical or
/// instructional purposes related to programming, coding, application development,
/// or information technology.  Permission for such use, copying, modification,
/// merger, publication, distribution, sublicensing, creation of derivative works,
/// or sale is expressly withheld.
///
/// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
/// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
/// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
/// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
/// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
/// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
/// THE SOFTWARE.

import AVFoundation
import UIKit

class DepthImageViewController: UIViewController {
  @IBOutlet weak var imageView: UIImageView!
  @IBOutlet weak var imageModeControl: UISegmentedControl!
  @IBOutlet weak var filterControl: UISegmentedControl!
  @IBOutlet weak var depthSlider: UISlider!
  
  @IBOutlet weak var radiusSlider: UISlider!
  
  /// The sample resource currently being displayed.
  var currentSampleImage: SampleImage? = nil

  /// An array of file `URL`'s for sample images bundled within the app.
  lazy var sampleImageURLs: [URL] = (Bundle.main.urls(
    forResourcesWithExtension: "heic",
    subdirectory: nil
  ) ?? []) + (Bundle.main.urls(
    forResourcesWithExtension: "jpg",
    subdirectory: nil
  ) ?? [])

  /// The context used for filtering images.
  let context = CIContext()

  /// A collection of filter methods that can be applied to images.
  lazy var depthFilters = DepthImageFilters(context: context)

  override func viewDidLoad() {
    super.viewDidLoad()
    
    // Load the first sample image
    guard let url = nextSampleImageURL() else { return }
    loadSample(withFileURL: url)
  }

  func nextSampleImageURL() -> URL? {
    guard
      let currentSample = currentSampleImage,
      let index = sampleImageURLs.firstIndex(of: currentSample.url)
      else {
        return sampleImageURLs.first
    }

    let nextIndex = (index + 1) % sampleImageURLs.count
    return sampleImageURLs[nextIndex]
  }

  override var prefersStatusBarHidden: Bool { true }
}

// MARK: Helper Methods

extension DepthImageViewController {
  func loadSample(withFileURL url: URL) {
    // Load the sample image
    guard let image = SampleImage(url: url) else { return }
    currentSampleImage = image

    // Set the segmented control to point to the original image
    imageModeControl.selectedSegmentIndex = ImageMode.original.rawValue
    
    // Update the image view
    updateView()
  }
  
  func updateView() {
    guard let sampleImage = currentSampleImage else { return }

    // Work out the current state
    let imageMode = ImageMode(rawValue: imageModeControl.selectedSegmentIndex)!
    let filter = FilterType(rawValue: filterControl.selectedSegmentIndex)!
    
    // Update the visible controls
    depthSlider.isHidden = imageMode.isDepthSliderHidden
    radiusSlider.isHidden = imageMode.isRadiusSliderHidden
    filterControl.isHidden = imageMode.isFilterControlHidden

    // Based on the UI configuration, update the image
    imageView.image = createImage(for: sampleImage, mode: imageMode, filter: filter)
  }

  func createImage(for image: SampleImage, mode: ImageMode, filter: FilterType) -> UIImage? {
    let focus = CGFloat(depthSlider.value)
    let radius = CGFloat(radiusSlider.value)

    switch (mode, filter) {
    case (.original, _):
      return image.original

    case (.depth, _):
      return image.depthData

    case (.mask, _):
      return depthFilters.createMaskImage(for: image, withFocus: focus)

    case (.filtered, .spotlight):
      return depthFilters.createSpotlightImage(for: image, withFocus: focus)

    case (.filtered, .color):
      return depthFilters.createColorHighlight(for: image, withFocus: focus)

    case (.filtered, .blur):
      return depthFilters.createFocalBlur(for: image, withFocus: focus, withRadius: radius)
    }
  }
}

// MARK: IBAction Methods

extension DepthImageViewController {
  @IBAction func sliderValueChanged(_ sender: UISlider) {
    updateView()
  }
  
  @IBAction func segmentedControlValueChanged(_ sender: UISegmentedControl) {
    updateView()
  }
  
  @IBAction func filterTypeChanged(_ sender: UISegmentedControl) {
    updateView()
  }
  
  @IBAction func imageTapped(_ sender: UITapGestureRecognizer) {
    guard let url = nextSampleImageURL() else { return }
    loadSample(withFileURL: url)
  }
}

// MARK: - Helpers

private extension ImageMode {
  var isDepthSliderHidden: Bool {
    switch self {
    case .original, .depth:
      return true
    case .mask, .filtered:
      return false
    }
  }
  
  var isRadiusSliderHidden: Bool {
    switch self {
    case .original, .depth:
      return true
    case .mask, .filtered:
      return false
    }
  }

  var isFilterControlHidden: Bool {
    switch self {
    case .original, .depth, .mask:
      return true
    case .filtered:
      return false
    }
  }
}
