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

import Foundation
import UIKit

class ChatRoom: NSObject {
  //1 declare your input and output streams. Using this pair of classes together allows you to create a socket-based connection between your app and the chat server. Naturally, you’ll send messages via the output stream and receive them via the input stream.
  var inputStream: InputStream!
  var outputStream: OutputStream!
  
  //2 store user
  var username = ""
  
  //3 cap data in single message
  let maxReadLength = 4096
  
  // Let's open a connection
  func setupNetworkConnection() {
    
    // 1 2 uninitialized socket streams withOUT auto memory management (Unmanaged)
    var readStream: Unmanaged<CFReadStream>?
    var writeStream: Unmanaged<CFWriteStream>?
    
    //2 bind R/W streams together and connect them to socket of host
    CFStreamCreatePairWithSocketToHost(kCFAllocatorDefault, "localhost" as CFString, 80, &readStream, &writeStream)
    
    
    /*
     
     Calling takeRetainedValue() on an unmanaged object allows you to simultaneously grab a retained reference and burn an unbalanced retain so the memory isn’t leaked later. Now you can use the input and output streams when you need them.
     */
    
    // Store retained references to initialized streams
    inputStream = readStream!.takeRetainedValue()
    outputStream = writeStream?.takeRetainedValue()
    
    // Add streams to run loop so the app will react to networking events properly
    
    inputStream.schedule(in: .current, forMode: .common)
    outputStream.schedule(in: .current, forMode: .common)
    
    // OPEN THE FLOOD GATES
    inputStream.open()
    outputStream.open()
    
  }
}

