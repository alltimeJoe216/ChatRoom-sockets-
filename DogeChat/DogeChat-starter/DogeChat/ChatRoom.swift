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

// Let's talk to the chatroom view controller
protocol ChatRoomDelegate: class {
  func received(message: Message)
}

class ChatRoom: NSObject {
  
  // Weak optional property to hold a reference to WHOMEVER decides to become the ChatRoom's delegate
  weak var delegate: ChatRoomDelegate?
  
  
  //1 declare your input and output streams. Using this pair of classes together allows you to create a socket-based connection between your app and the chat server. Naturally, you’ll send messages via the output stream and receive them via the input stream.
  var inputStream: InputStream!
  var outputStream: OutputStream!
  
  //2 store user
  var username = ""
  
  //3 cap data in single message
  let maxReadLength = 4096
  
  //MARK: - Setup Network Connection (SEE FUNCTION NAME...........)
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
    
    /// Per the extension, set the delegate
    inputStream.delegate = self
    
    // Add streams to run loop so the app will react to networking events properly
    
    inputStream.schedule(in: .current, forMode: .common)
    outputStream.schedule(in: .current, forMode: .common)
    
    // OPEN THE FLOOD GATES
    inputStream.open()
    outputStream.open()
  }
  
  //MARK: - Join Chat -
  
  func joinChat(username: String) {
    //1 Construct message using chatroom protocol
    let data = "iam:\(username)".data(using: .utf8)!
    
    //2 save the name so you can use it to send the chat messages
    self.username = username
    
    //3 provides a way to work with an unsafe pointer version of some data within the safe confines of a closure
    _ = data.withUnsafeBytes {
      guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        print("Error joining chat")
        return
      }
      //4 Write message to output stream. write() takes a reference to an unsafe pointer to bytes as it's first argument, which is created above (pointer)
      outputStream.write(pointer, maxLength: data.count)
    }
  }
  
  //MARK: - Sending Message
  
  /*
   /// - Prepares message with prefix 'msg:'
   /// - Write to pointer
   
   */
  func send(message: String) {
    let data = "msg:\(message)".data(using: .utf8)!
    
    _ = data.withUnsafeBytes {
      guard let pointer = $0.baseAddress?.assumingMemoryBound(to: UInt8.self) else {
        print("Error joining chat")
        return
      }
      outputStream.write(pointer, maxLength: data.count)
    }
  }
  
  //MARK: - End session, close stream, remove from run loop
  
  func stopChatSession() {
    inputStream.close()
    outputStream.close()
  }
}

// MARK: - Handle incoming messages / Stream
extension ChatRoom: StreamDelegate {
  
  func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
    switch eventCode {
    case .hasBytesAvailable:
      print("new message received") // There's an incoming message to read
      readAvailableBytes(stream: aStream as! InputStream) // We have a buffer full of bytes
    
    case .endEncountered:
      stopChatSession() /// Close streams and remove from run loop
    case .errorOccurred:
      print("error occurred")
    case .hasSpaceAvailable:
      print("has space available")
    default:
      print("some other event...")
    }
  }
  
  // Handle incoming messages
  
  private func readAvailableBytes(stream: InputStream) {
    //1 Buffer to read incoming bytes
    let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: maxReadLength)
    
    //2 loop as long as the input stream has bytes to read
    while stream.hasBytesAvailable {
      //3 at every point, call read() which will read bytes from the stream and put them into the buffer
      let numberOfBytesRead = inputStream.read(buffer, maxLength: maxReadLength)
      
      //4 if call returns a negative value, some error occured and let's bounce out this thang
      if numberOfBytesRead < 0, let error = stream.streamError {
        print(error)
        break
      }
      
      // Construct the Message object (configured below)
      if let message =
          processedMessageString(buffer: buffer, length: numberOfBytesRead) {
        // Notify interested parties
        delegate?.received(message: message) // MESSAGE
      }
    }
  }
  
  // MARK: - Turn buffer into a Message object
  private func processedMessageString(buffer: UnsafeMutablePointer<UInt8>,
                                      length: Int) -> Message? {
    
    //1 initialize a String using the buffer and length that's passed in
    guard
      let stringArray = String(
        bytesNoCopy: buffer,
        length: length,
        encoding: .utf8,
        freeWhenDone: true)?.components(separatedBy: ":"),
      let name = stringArray.first,
      let message = stringArray.last
    else {
      return nil
    }
    //2 figure out if you or someone else sent the message based on the name. In a production app, you'd want to use some kind of unique token, but for now, this is good enough.
    
    let messageSender: MessageSender =
      (name == self.username) ? .ourself : .someoneElse
    //3 construct message
    return Message(message: message, messageSender: messageSender, username: name)
  }
}

