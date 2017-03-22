DeclareModule instance
  EnableExplicit
  
  Prototype receiveCallback(text$)
  
  Declare create(port, receiveFn.receiveCallback)
  Declare free()
  Declare sendString(text$)
  
EndDeclareModule

 

Module instance
  #BufferSize = 1024
  
  CompilerIf Not  #PB_Compiler_Thread 
    CompilerError "Please build threadsafe"
  CompilerEndIf
  
  Global _port
  Global _server
  Global _thread
  Global _stop
  Global callback.receiveCallback
  
  Procedure listener(server)
    ; wait for incomming connections
    Protected len, received$
    Protected *buffer
    *buffer = AllocateMemory(#BufferSize)
    
    Repeat
      If NetworkServerEvent(server) = #PB_NetworkEvent_Data
        Debug "instance::listener() - receive data..."
        received$ = ""
        Repeat 
          len = ReceiveNetworkData(EventClient(), *buffer, #BufferSize)
          received$ + PeekS(*buffer, len, #PB_UTF8)
        Until len < #BufferSize
        
        Debug "instance::listener() - received: "+received$
        ; send received text to callback
        If callback
          callback(received$)
        EndIf
        
      Else
        Delay(100)
      EndIf
    Until _stop
    
    CloseNetworkServer(server)
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure create(port, receiveFn.receiveCallback)
    If InitNetwork()
      _port = port
      callback = receiveFn
      
      _server = CreateNetworkServer(#PB_Any, _port, #PB_Network_TCP, "127.0.0.1")
      If _server
        _stop = #False
        _thread = CreateThread(@listener(), _server)
        
        If Not _thread
          CloseNetworkServer(_server)
          _server = #Null
        EndIf
      EndIf
      
      If _server And _thread
        ProcedureReturn #True
      EndIf
      ProcedureReturn #False
    EndIf
  EndProcedure

  Procedure free()
    Protected time
    
    _stop = #True
    time = ElapsedMilliseconds()
    While _thread And IsThread(_thread) And (ElapsedMilliseconds() - time) < 500
      Delay(10)
    Wend
    
    If _thread And IsThread(_thread)
      KillThread(_thread)
    EndIf
    _thread = #Null
    _stop   = #False
    
    ProcedureReturn #True
  EndProcedure
  
  Procedure sendString(text$)
    Protected id, len
    id = OpenNetworkConnection("127.0.0.1", _port, #PB_Network_TCP, 1000)
    If id
      len = SendNetworkString(id, text$, #PB_UTF8)
      CloseNetworkConnection(id)
      ProcedureReturn len
    EndIf
    ProcedureReturn #False
  EndProcedure
  
EndModule


CompilerIf #PB_Compiler_IsMainFile
  
  #PORT = 14213
  
  Procedure exit()
    ; exit program
    instance::free()
    End
  EndProcedure
  
  Procedure receiveCallback(text$)
    Debug "callback: "+text$
    SetGadgetText(0, "Got a message: "+text$)
  EndProcedure
  
  
  If instance::create(#PORT, @receiveCallback())
    ;this is the first instance
    
    OpenWindow(0, 0, 0, 500, 200, "Test", #PB_Window_SystemMenu | #PB_Window_ScreenCentered)
    TextGadget(0, 5, 5, 490, 190, "")
    BindEvent(#PB_Event_CloseWindow, @exit(), 0)
    
    Repeat
      WaitWindowEvent(100)
    ForEver
  Else
    ; Either another instance is running or port is blocked by another program...
    Debug "send message"
    instance::sendString("This is a test!")
  EndIf

CompilerEndIf