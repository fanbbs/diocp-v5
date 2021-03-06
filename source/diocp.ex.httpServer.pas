(*
  *	 Unit owner: D10.Mofen, delphi iocp framework author
  *         homePage: http://www.Diocp.org
  *	       blog: http://www.cnblogs.com/dksoft

  *   2015-02-22 08:29:43
  *     DIOCP-V5 发布

  *    Http协议处理单元
  *    其中大部分思路来自于delphi iocp framework中的iocp.HttpServer
  *
*)
unit diocp.ex.httpServer;

interface

uses
  Classes, StrUtils, SysUtils, utils.buffer, utils.strings,
  diocp.tcp.server;

type
  TDiocpHttpState = (hsCompleted, hsRequest { 接收请求 } , hsRecvingPost { 接收数据 } );
  TDiocpHttpResponse = class;
  TDiocpHttpClientContext = class;

  TDiocpHttpRequest = class(TObject)
  private
    FDiocpContext: TDiocpHttpClientContext;

    /// 头信息
    FHttpVersion: Word; // 10, 11

    FRequestVersionStr: string;

    FRequestMethod: string;
    FRequestUrl: String;

    FRequestParamsList: TStringList; // TODO:存放http参数的StringList

    FContextType: string;
    FContextLength: Int64;
    FKeepAlive: Boolean;
    FRequestAccept: String;
    FRequestReferer: String;
    FRequestAcceptLanguage: string;
    FRequestAcceptEncoding: string;
    FRequestUserAgent: string;
    FRequestAuth: string;
    FRequestCookies: string;
    FRequestHostName: string;
    FRequestHostPort: string;

    FXForwardedFor: string;

    FRawHeaderData: TMemoryStream;

    FRawPostData: TMemoryStream;

    FPostDataLen: Integer;

    FRequestHeader: TStringList;

    FResponse: TDiocpHttpResponse;

    /// <summary>
    /// 是否有效的Http 请求方法
    /// </summary>
    /// <returns>
    /// 0: 数据不足够进行解码
    /// 1: 有效的数据头
    /// 2: 无效的请求数据头
    /// </returns>
    function DecodeHttpRequestMethod: Integer;

    /// <summary>
    /// 解码Http请求参数信息
    /// </summary>
    /// <returns>
    /// 1: 有效的Http参数数据
    /// </returns>
    function DecodeHttpRequestHeader: Integer;
    
    /// <summary>
    /// 接收到的Buffer,写入数据
    /// </summary>
    procedure WriteRawBuffer(const buffer: Pointer; len: Integer);
  protected
    function MakeHeader(const Status, ContType, Header: string;
      pvContextLength: Integer): string;
  public
    constructor Create;
    destructor Destroy; override;


    /// <summary>
    ///   将Post的原始数据解码，放到参数列表中
    ///   在OnDiocpHttpRequest中调用
    /// </summary>
    procedure DecodePostDataParam(
      {$IFDEF UNICODE} pvEncoding:TEncoding {$ELSE}pvUseUtf8Decode:Boolean{$ENDIF});

    /// <summary>
    ///   清理
    /// </summary>
    procedure Clear;

    property ContextLength: Int64 read FContextLength;
    /// <summary>
    ///   原始的Post过来的数据
    /// </summary>
    property RawPostData: TMemoryStream read FRawPostData;

    /// <summary>
    ///   请求的头信息
    /// </summary>
    property RequestHeader: TStringList read FRequestHeader;

    /// <summary>
    ///   从头信息解码器出来的Url
    /// </summary>
    property RequestUrl: String read FRequestUrl;

    /// <summary>
    /// 得到客户端请求方式
    /// </summary>
    property RequestMethod: string read FRequestMethod;

    /// <summary>
    /// 得到客户端主机IP地址
    /// </summary>
    property RequestHostName: string read FRequestHostName;

    /// <summary>
    /// 得到客户端主机端口
    /// </summary>
    property RequestHostPort: string read FRequestHostPort;

    /// <summary>
    /// Http响应对象，回写数据
    /// </summary>
    property Response: TDiocpHttpResponse read FResponse;

    /// <summary>
    ///   从Url和Post数据中得到的参数信息: key = value
    /// </summary>
    property RequestParamsList: TStringList read FRequestParamsList;

    /// <summary>
    /// 应答完毕，发送会客户端
    /// </summary>
    procedure ResponseEnd;

    /// <summary>
    ///  关闭连接
    /// </summary>
    procedure CloseContext;

    /// <summary>
    /// 得到http请求参数
    /// </summary>
    /// <params>
    /// <param name="ParamsKey">http请求参数的key</param>
    /// </params>
    /// <returns>
    /// 1: http请求参数的值
    /// </returns>
    function GetRequestParam(ParamsKey: string): string;

    /// <summary>
    /// 解析POST和GET参数
    /// </summary>
    /// <pvParamText>
    /// <param name="pvParamText">要解析的全部参数</param>
    /// </pvParamText>
    procedure ParseParams(pvParamText: string);

  end;

  TDiocpHttpResponse = class(TObject)
  private
    FResponseHeader: string;
    FContentType: String;
    FData: TMemoryStream;
  public
    procedure Clear;
    constructor Create;
    destructor Destroy; override;
    procedure WriteBuf(pvBuf: Pointer; len: Cardinal);
    procedure WriteString(pvString: string);

    property ContentType: String read FContentType write FContentType;
  end;

  /// <summary>
  /// Http 客户端连接
  /// </summary>
  TDiocpHttpClientContext = class(TIocpClientContext)
  private
    FHttpState: TDiocpHttpState;
    FRequest: TDiocpHttpRequest;
  public
    constructor Create; override;
    destructor Destroy; override;
  protected
    /// <summary>
    /// 归还到对象池，进行清理工作
    /// </summary>
    procedure DoCleanUp; override;

    /// <summary>
    /// 接收到客户端的Http协议数据, 进行解码成TDiocpHttpRequest，响应Http请求
    /// </summary>
    procedure OnRecvBuffer(buf: Pointer; len: Cardinal; ErrCode: Word);
      override;
  end;

{$IFDEF UNICODE}

  /// <summary>
  /// Request事件类型
  /// </summary>
  TOnDiocpHttpRequestEvent = reference to procedure(pvRequest: TDiocpHttpRequest);
{$ELSE}
  /// <summary>
  /// Request事件类型
  /// </summary>
  TOnDiocpHttpRequestEvent = procedure(pvRequest: TDiocpHttpRequest) of object;
{$ENDIF}

  /// <summary>
  /// Http 解析服务
  /// </summary>
  TDiocpHttpServer = class(TDiocpTcpServer)
  private
    FOnDiocpHttpRequest: TOnDiocpHttpRequestEvent;
    FOnDiocpHttpRequestPostDone: TOnDiocpHttpRequestEvent;

    /// <summary>
    /// 响应Http请求， 执行响应事件
    /// </summary>
    procedure DoRequest(pvRequest: TDiocpHttpRequest);

    /// <summary>
    ///   响应Post数据事件
    /// </summary>
    procedure DoRequestPostDataDone(pvRequest: TDiocpHttpRequest);

  public
    constructor Create(AOwner: TComponent); override;



    /// <summary>
    ///   当Http请求的Post数据完成后触发的事件
    ///   用来处理解码一些数据,比如Post的参数
    /// </summary>
    property OnDiocpHttpRequestPostDone: TOnDiocpHttpRequestEvent read
        FOnDiocpHttpRequestPostDone write FOnDiocpHttpRequestPostDone;

    /// <summary>
    /// 响应Http请求事件
    /// </summary>
    property OnDiocpHttpRequest: TOnDiocpHttpRequestEvent read FOnDiocpHttpRequest
        write FOnDiocpHttpRequest;

  end;


implementation

function FixHeader(const Header: string): string;
begin
  Result := Header;
  if (RightStr(Header, 4) <> #13#10#13#10) then
  begin
    if (RightStr(Header, 2) = #13#10) then
      Result := Result + #13#10
    else
      Result := Result + #13#10#13#10;
  end;
end;

procedure TDiocpHttpRequest.Clear;
begin
  FRawHeaderData.Clear;
  FRawPostData.Clear;
  FRequestUrl := '';
  FRequestVersionStr := '';
  FRequestMethod := '';
  FRequestCookies := '';
  FRequestParamsList.Clear;
  FContextLength := 0;
  FPostDataLen := 0;
  FResponse.Clear;  
end;

procedure TDiocpHttpRequest.CloseContext;
begin
  FDiocpContext.PostWSACloseRequest();
end;

function TDiocpHttpRequest.GetRequestParam(ParamsKey: string): string;
var
  lvTemp: string; // 返回的参数值
  lvParamsCount: Integer; // 参数数量
  I: Integer;
begin
  Result := '';

  lvTemp := ''; // 返回的参数值默认值为空

  // 得到提交过来的参数的数量
  lvParamsCount := self.FRequestParamsList.Count;

  // 判断是否有提交过来的参数数据
  if lvParamsCount = 0 then exit;

  // 循环比较每一组参数的key，是否和当前输入一样
  for I := 0 to lvParamsCount - 1 do
  begin 
    if Trim(self.FRequestParamsList.Names[I]) = Trim(ParamsKey) then
    begin
      lvTemp := Trim(self.FRequestParamsList.ValueFromIndex[I]);
      Break;
    end;
  end; 

  Result := lvTemp;
end;

constructor TDiocpHttpRequest.Create;
begin
  inherited Create;
  FRawHeaderData := TMemoryStream.Create();
  FRawPostData := TMemoryStream.Create();
  FRequestHeader := TStringList.Create();
  FResponse := TDiocpHttpResponse.Create();

  FRequestParamsList := TStringList.Create; // TODO:创建存放http参数的StringList
end;

destructor TDiocpHttpRequest.Destroy;
begin
  FreeAndNil(FResponse);
  FRawPostData.Free;
  FRawHeaderData.Free;
  FRequestHeader.Free;

  FreeAndNil(FRequestParamsList); // TODO:释放存放http参数的StringList

  inherited Destroy;
end;

function TDiocpHttpRequest.DecodeHttpRequestMethod: Integer;
var
  lvBuf: PAnsiChar;
begin
  Result := 0;
  if FRawHeaderData.Size <= 7 then
    Exit;

  lvBuf := FRawHeaderData.Memory;

  if FRequestMethod <> '' then
  begin
    Result := 1; // 已经解码
    Exit;
  end;

  // 请求方法（所有方法全为大写）有多种，各个方法的解释如下：
  // GET     请求获取Request-URI所标识的资源
  // POST    在Request-URI所标识的资源后附加新的数据
  // HEAD    请求获取由Request-URI所标识的资源的响应消息报头
  // PUT     请求服务器存储一个资源，并用Request-URI作为其标识
  // DELETE  请求服务器删除Request-URI所标识的资源
  // TRACE   请求服务器回送收到的请求信息，主要用于测试或诊断
  // CONNECT 保留将来使用
  // OPTIONS 请求查询服务器的性能，或者查询与资源相关的选项和需求
  // 应用举例：
  // GET方法：在浏览器的地址栏中输入网址的方式访问网页时，浏览器采用GET方法向服务器获取资源，eg:GET /form.html HTTP/1.1 (CRLF)
  //
  // POST方法要求被请求服务器接受附在请求后面的数据，常用于提交表单。

  Result := 1;
  // HTTP 1.1 支持8种请求
  if (StrLIComp(lvBuf, 'GET', 3) = 0) then
  begin
    FRequestMethod := 'GET';
  end
  else if (StrLIComp(lvBuf, 'POST', 4) = 0) then
  begin
    FRequestMethod := 'POST';
  end
  else if (StrLIComp(lvBuf, 'PUT', 3) = 0) then
  begin
    FRequestMethod := 'PUT';
  end
  else if (StrLIComp(lvBuf, 'HEAD', 3) = 0) then
  begin
    FRequestMethod := 'HEAD';
  end
  else if (StrLIComp(lvBuf, 'OPTIONS', 7) = 0) then
  begin
    FRequestMethod := 'OPTIONS';
  end
  else if (StrLIComp(lvBuf, 'DELETE', 6) = 0) then
  begin
    FRequestMethod := 'DELETE';
  end
  else if (StrLIComp(lvBuf, 'TRACE', 5) = 0) then
  begin
    FRequestMethod := 'TRACE';
  end
  else if (StrLIComp(lvBuf, 'CONNECT', 7) = 0) then
  begin
    FRequestMethod := 'CONNECT';
  end
  else
  begin
    Result := 2;
  end;
end;

function TDiocpHttpRequest.DecodeHttpRequestHeader: Integer;
var
  lvRawString: AnsiString;
  lvMethod, lvRawTemp: AnsiString;
  lvRequestCmdLine, lvTempStr, lvRemainStr: String;
  I, J: Integer;
  p : PChar;
begin
  Result := 1;
  SetLength(lvRawString, FRawHeaderData.Size);
  FRawHeaderData.Position := 0;
  FRawHeaderData.Read(lvRawString[1], FRawHeaderData.Size);
  FRequestHeader.Text := lvRawString;

  // GET /test?v=abc HTTP/1.1
  lvRequestCmdLine := FRequestHeader[0];
  P := PChar(lvRequestCmdLine);
  FRequestHeader.Delete(0);

  I := 1;
  while (I <= Length(lvRequestCmdLine)) and (lvRequestCmdLine[I] <> ' ') do
    Inc(I);
  // 请求方法(GET, POST, PUT, HEAD...)
  lvMethod := UpperCase(Copy(lvRequestCmdLine, 1, I - 1));
  Inc(I);
  while (I <= Length(lvRequestCmdLine)) and (lvRequestCmdLine[I] = ' ') do
    Inc(I);
  J := I;
  while (I <= Length(lvRequestCmdLine)) and (lvRequestCmdLine[I] <> ' ') do
    Inc(I);

  // 请求参数及路径
  lvTempStr := Copy(lvRequestCmdLine, J, I - J);
  // 解析参数
  J := Pos('?', lvTempStr);

  if (J <= 0) then
  begin
    FRequestUrl := lvTempStr;
    lvRawTemp := '';

    FRequestUrl := URLDecode(FRequestUrl);
    // Utf8解码
    FRequestUrl := Utf8Decode(FRequestUrl);

  end
  else
  begin
    FRequestUrl := Copy(lvTempStr, 1, J - 1);
    FRequestUrl := URLDecode(FRequestUrl);
    // Utf8解码
    FRequestUrl := Utf8Decode(FRequestUrl);


    // Url中的参数
    lvRawTemp := Copy(lvTempStr, J + 1, MaxInt);

    //
    lvTempStr := URLDecode(lvRawTemp);

    // TODO:解析GET和POST参数
    if Trim(lvTempStr) <> '' then
    begin
      ParseParams(lvTempStr);
    end;

  end;

  Inc(I);
  while (I <= Length(lvRequestCmdLine)) and (lvRequestCmdLine[I] = ' ') do
    Inc(I);
  J := I;
  while (I <= Length(lvRequestCmdLine)) and (lvRequestCmdLine[I] <> ' ') do
    Inc(I);

  // 请求的HTTP版本
  FRequestVersionStr := Trim(UpperCase(Copy(lvRequestCmdLine, J, I - J)));

  if (FRequestVersionStr = '') then
    FRequestVersionStr := 'HTTP/1.0';
  if (lvTempStr = 'HTTP/1.0') then
  begin
    FHttpVersion := 10;
    FKeepAlive := false; // 默认为false
  end
  else
  begin
    FHttpVersion := 11;
    FKeepAlive := true; // 默认为true
  end;

  FContextLength := 0;


  // eg：POST /reg.jsp HTTP/ (CRLF)
  // Accept:image/gif,image/x-xbit,... (CRLF)
  // ...
  // HOST:www.guet.edu.cn (CRLF)
  // Content-Length:22 (CRLF)
  // Connection:Keep-Alive (CRLF)
  // Cache-Control:no-cache (CRLF)
  // (CRLF)         //该CRLF表示消息报头已经结束，在此之前为消息报头
  // user=jeffrey&pwd=1234  //此行以下为提交的数据
  //
  // HEAD方法与GET方法几乎是一样的，对于HEAD请求的回应部分来说，它的HTTP头部中包含的信息与通过GET请求所得到的信息是相同的。利用这个方法，不必传输整个资源内容，就可以得到Request-URI所标识的资源的信息。该方法常用于测试超链接的有效性，是否可以访问，以及最近是否更新。
  // 2、请求报头后述
  // 3、请求正文(略)

  for I := 0 to FRequestHeader.Count - 1 do
  begin
    lvRequestCmdLine := FRequestHeader[I];
    P := PChar(lvRequestCmdLine);

    // 获取右边的字符
    lvTempStr := LeftUntil(P, [':']);
    SkipChars(P, [':', ' ']);

    // 获取剩余的字符
    lvRemainStr := LeftUntil(P, []);

    if (lvRequestCmdLine = '') then
      Continue;

    if SameText(lvTempStr, 'Content-Type') then
    begin
      FContextType := lvRemainStr;
    end else if SameText(lvTempStr, 'Content-Length') then
    begin
      FContextLength := StrToInt64Def(lvRemainStr, -1);
    end else if SameText(lvTempStr, 'Accept') then
    begin
      FRequestAccept := lvRemainStr;
    end else if SameText(lvTempStr, 'Referer') then
    begin
      FRequestReferer := lvRemainStr;
    end else if SameText(lvTempStr, 'Accept-Language') then
    begin
      FRequestAcceptLanguage := lvRemainStr;
    end else if SameText(lvTempStr, 'Accept-Encoding') then
    begin
      FRequestAcceptEncoding := lvRemainStr;
    end else if SameText(lvTempStr, 'User-Agent')then
    begin
      FRequestUserAgent := lvRemainStr;
    end else if SameText(lvTempStr, 'Authorization') then
    begin
      FRequestAuth := lvRemainStr;
    end else if SameText(lvTempStr, 'Cookie') then
    begin
      FRequestCookies := lvRemainStr;
    end else if SameText(lvTempStr, 'Host') then
    begin
      lvTempStr := lvRemainStr;
      J := Pos(':', lvTempStr);
      if J > 0 then
      begin
        FRequestHostName := Copy(lvTempStr, 1, J - 1);
        FRequestHostPort := Copy(lvTempStr, J + 1, 100);
      end
      else
      begin
        FRequestHostName := lvTempStr;
        FRequestHostPort := IntToStr((FDiocpContext).Owner.Port);
      end;
    end
    else if SameText(lvTempStr, 'Connection') then
    begin
      // HTTP/1.0 默认KeepAlive=False，只有显示指定了Connection: keep-alive才认为KeepAlive=True
      // HTTP/1.1 默认KeepAlive=True，只有显示指定了Connection: close才认为KeepAlive=False
      if FHttpVersion = 10 then
        FKeepAlive := SameText(lvRemainStr, 'keep-alive')
      else if SameText(lvRemainStr, 'close') then
        FKeepAlive := false;
    end
    else if SameText(lvTempStr, 'X-Forwarded-For') then
      FXForwardedFor := lvRemainStr;
  end;
end;




procedure TDiocpHttpRequest.DecodePostDataParam({$IFDEF UNICODE} pvEncoding:TEncoding {$ELSE}pvUseUtf8Decode:Boolean{$ENDIF});
var
  lvRawData:AnsiString;
  lvRawParams, s:String;
  i:Integer;
{$IFDEF UNICODE}
var
  lvBytes:TBytes;
{$ELSE}
{$ENDIF}
begin
  // 读取原始数据
  SetLength(lvRawData, FRawPostData.Size);
  FRawPostData.Position := 0;
  FRawPostData.Read(lvRawData[1], FRawPostData.Size);

  // 先放入到Strings
  SplitStrings(lvRawData, FRequestParamsList, ['&']);


  for i := 0 to FRequestParamsList.Count - 1 do
  begin
    lvRawData := URLDecode(FRequestParamsList.ValueFromIndex[i]);
    {$IFDEF UNICODE}
    if pvEncoding <> nil then
    begin
      // 字符编码转换
      SetLength(lvBytes, length(lvRawData));
      Move(PByte(lvRawData)^, lvBytes[0], Length(lvRawData));
      s := pvEncoding.GetString(lvBytes);
    end else
    begin
      s := lvRawData;
    end;
    {$ELSE}
    if pvUseUtf8Decode then
    begin
      s := UTF8Decode(lvRawData);
    end else
    begin
      s := lvRawData;
    end;
    {$ENDIF}

    FRequestParamsList.ValueFromIndex[i] := s;
  end;
end;


/// <summary>
///  解析POST和GET参数
/// </summary>
/// <pvParamText>
/// <param name="pvParamText">要解析的全部参数</param>
/// </pvParamText>
procedure TDiocpHttpRequest.ParseParams(pvParamText: string);
begin
  SplitStrings(pvParamText, FRequestParamsList, ['&']);
end;

function TDiocpHttpRequest.MakeHeader(const Status, ContType, Header: string;
  pvContextLength: Integer): string;
begin
  Result := '';

  if (Status = '') then
    Result := Result + FRequestVersionStr + ' 200 OK' + #13#10
  else
    Result := Result + FRequestVersionStr + ' ' + Status + #13#10;

  if (ContType = '') then
    Result := Result + 'Content-Type: text/html' + #13#10
  else
    Result := Result + 'Content-Type: ' + ContType + #13#10;

  if (pvContextLength > 0) then
    Result := Result + 'Content-Length: ' + IntToStr(pvContextLength) + #13#10;
  // Result := Result + 'Cache-Control: no-cache'#13#10;

  if FKeepAlive then
    Result := Result + 'Connection: keep-alive'#13#10
  else
    Result := Result + 'Connection: close'#13#10;

  Result := Result + 'Server: DIOCP3/1.0'#13#10;

  if (Header <> '') then
    Result := Result + FixHeader(Header)
  else
    Result := Result + #13#10;
end;

procedure TDiocpHttpRequest.ResponseEnd;
var
  lvFixedHeader: AnsiString;
  len: Integer;
begin
  lvFixedHeader := MakeHeader('', FResponse.FContentType,
    FResponse.FResponseHeader, FResponse.FData.Size);

  // FResponseSize必须准确指定发送的数据包大小
  // 用于在发送完之后(Owner.TriggerClientSentData)断开客户端连接
  if lvFixedHeader <> '' then
  begin
    len := Length(lvFixedHeader);
    FDiocpContext.PostWSASendRequest(PAnsiChar(lvFixedHeader), len);
  end;

  if FResponse.FData.Size > 0 then
  begin
    FDiocpContext.PostWSASendRequest(FResponse.FData.Memory,
      FResponse.FData.Size);
  end;

  if not FKeepAlive then
  begin
    FDiocpContext.PostWSACloseRequest;
  end;
end;

procedure TDiocpHttpRequest.WriteRawBuffer(const buffer: Pointer; len: Integer);
begin
  FRawHeaderData.WriteBuffer(buffer^, len);
end;

procedure TDiocpHttpResponse.Clear;
begin
  FContentType := '';
  FData.Clear;
  FResponseHeader := '';
end;

constructor TDiocpHttpResponse.Create;
begin
  inherited Create;
  FData := TMemoryStream.Create();
end;

destructor TDiocpHttpResponse.Destroy;
begin
  FreeAndNil(FData);
  inherited Destroy;
end;

procedure TDiocpHttpResponse.WriteBuf(pvBuf: Pointer; len: Cardinal);
begin
  FData.Write(pvBuf^, len);
end;

procedure TDiocpHttpResponse.WriteString(pvString: string);
var
  lvRawString: AnsiString;
begin
  lvRawString := AnsiString(pvString);
  FData.WriteBuffer(PAnsiChar(lvRawString)^, Length(lvRawString));
end;

constructor TDiocpHttpClientContext.Create;
begin
  inherited Create;
  FRequest := TDiocpHttpRequest.Create();
  FRequest.FDiocpContext := self;
end;

destructor TDiocpHttpClientContext.Destroy;
begin
  FreeAndNil(FRequest);
  inherited Destroy;
end;

procedure TDiocpHttpClientContext.DoCleanUp;
begin
  inherited;
  FHttpState := hsCompleted;
end;

procedure TDiocpHttpClientContext.OnRecvBuffer(buf: Pointer; len: Cardinal;
  ErrCode: Word);
var
  lvTmpBuf: PAnsiChar;
  CR, LF: Integer;
  lvRemain: Cardinal;
begin
  inherited;
  lvTmpBuf := buf;
  CR := 0;
  LF := 0;
  lvRemain := len;
  while (lvRemain > 0) do
  begin
    if FHttpState = hsCompleted then
    begin // 完成后重置，重新处理下一个包
      FRequest.Clear;
      FHttpState := hsRequest;
    end;

    if (FHttpState = hsRequest) then
    begin
      case lvTmpBuf^ of
        #13:
          Inc(CR);
        #10:
          Inc(LF);
      else
        CR := 0;
        LF := 0;
      end;

      // 写入请求数据
      FRequest.WriteRawBuffer(lvTmpBuf, 1);

      if FRequest.DecodeHttpRequestMethod = 2 then
      begin // 无效的Http请求
        self.RequestDisconnect('无效的Http请求', self);
        Exit;
      end;

      // 请求数据已接收完毕(#13#10#13#10是HTTP请求结束的标志)
      if (CR = 2) and (LF = 2) then
      begin
        if FRequest.DecodeHttpRequestHeader = 0 then
        begin
          self.RequestDisconnect('无效的Http协议数据', self);
          Exit;
        end;

        if SameText(FRequest.FRequestMethod, 'POST') or
          SameText(FRequest.FRequestMethod, 'PUT') then
        begin
          // 无效的Post请求直接断开
          if (FRequest.FContextLength <= 0) then
          begin
            self.RequestDisconnect('无效的POST/PUT请求数据', self);
            Exit;
          end;
          // 改变Http状态, 进入接受数据状态
          FHttpState := hsRecvingPost;
        end
        else
        begin
          FHttpState := hsCompleted;
          // 触发事件
          TDiocpHttpServer(FOwner).DoRequest(FRequest);
          Break;
        end;
      end;
    end
    else if (FHttpState = hsRecvingPost) then
    begin
      FRequest.FRawPostData.Write(lvTmpBuf^, 1);
      Inc(FRequest.FPostDataLen);

      if FRequest.FPostDataLen >= FRequest.FContextLength then
      begin
        FHttpState := hsCompleted;

        // 触发事件
        TDiocpHttpServer(FOwner).DoRequestPostDataDone(FRequest);

        // 触发事件
        TDiocpHttpServer(FOwner).DoRequest(FRequest);

      end;
    end;
    Dec(lvRemain);
    Inc(lvTmpBuf);
  end;
end;

{ TDiocpHttpServer }

constructor TDiocpHttpServer.Create(AOwner: TComponent);
begin
  inherited;
  KeepAlive := false;
  registerContextClass(TDiocpHttpClientContext);
end;

procedure TDiocpHttpServer.DoRequest(pvRequest: TDiocpHttpRequest);
begin
  if Assigned(FOnDiocpHttpRequest) then
  begin
    FOnDiocpHttpRequest(pvRequest);
  end;
end;

procedure TDiocpHttpServer.DoRequestPostDataDone(pvRequest: TDiocpHttpRequest);
var
  lvRawData:AnsiString;
begin 
  if Assigned(FOnDiocpHttpRequestPostDone) then
  begin
    FOnDiocpHttpRequestPostDone(pvRequest);
  end;
end;

end.
