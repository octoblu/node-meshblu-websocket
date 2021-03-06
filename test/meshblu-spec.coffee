{afterEach, beforeEach, describe, it} = global
{expect} = require 'chai'
{EventEmitter} = require 'events'
sinon          = require 'sinon'
Meshblu        = require '../src/meshblu'

describe 'Meshblu', ->
  beforeEach ->
    @ws = new WebSocket
    @WebSocket = sinon.stub().returns @ws

  describe 'SRV resolve', ->
    describe 'when constructed with resolveSrv true, and a hostname', ->
      it 'should throw an error', ->
        expect(=> new Meshblu resolveSrv: true, hostname: 'foo.co').to.throw(
          'hostname parameter is only valid when the parameter resolveSrv is false'
        )

    describe 'when constructed with resolveSrv true, and nothing else', ->
      beforeEach ->
        @dns = resolveSrv: sinon.stub()
        @websocket = new EventEmitter
        @WebSocket = sinon.spy => @websocket

        options = resolveSrv: true
        dependencies = {@dns, @WebSocket}

        @sut = new Meshblu options, dependencies

      describe 'when connect is called', ->
        beforeEach 'making the request', (done) ->
          @dns.resolveSrv.withArgs('_meshblu._wss.octoblu.com').yields null, [{
            name: 'mesh.biz'
            port: 34
            priority: 1
            weight: 100
          }]
          @sut.connect done
          @websocket.emit 'message', '["ready"]'

        it 'should instantiate the WebSocket with the resolved url', ->
          expect(@WebSocket).to.have.been.calledWithNew
          expect(@WebSocket).to.have.been.calledWith 'wss:mesh.biz:34/ws/v2'

    describe 'when constructed with resolveSrv and secure true', ->
      beforeEach ->
        @dns = resolveSrv: sinon.stub()
        @websocket = new EventEmitter
        @WebSocket = sinon.spy => @websocket

        options = resolveSrv: true, service: 'meshblu', domain: 'octoblu.com', secure: true
        dependencies = {@dns, @WebSocket}

        @sut = new Meshblu options, dependencies

      describe 'when connect is called', ->
        beforeEach 'making the request', (done) ->
          @dns.resolveSrv.withArgs('_meshblu._wss.octoblu.com').yields null, [{
            name: 'mesh.biz'
            port: 34
            priority: 1
            weight: 100
          }]
          @sut.connect done
          @websocket.emit 'message', '["ready"]'

        it 'should instantiate the WebSocket with the resolved url', ->
          expect(@WebSocket).to.have.been.calledWithNew
          expect(@WebSocket).to.have.been.calledWith 'wss:mesh.biz:34/ws/v2'

    describe 'when constructed with resolveSrv and secure false', ->
      beforeEach ->
        @dns = resolveSrv: sinon.stub()
        @websocket = new EventEmitter
        @WebSocket = sinon.spy => @websocket

        options = resolveSrv: true, service: 'meshblu', domain: 'octoblu.com', secure: false
        dependencies = {@dns, @WebSocket}

        @sut = new Meshblu options, dependencies

      describe 'when connect is called', ->
        beforeEach 'making the request', (done) ->
          @dns.resolveSrv.withArgs('_meshblu._ws.octoblu.com').yields null, [{
            name: 'insecure.xxx'
            port: 80
            priority: 1
            weight: 100
          }]
          @sut.connect done
          @websocket.emit 'message', '["ready"]'

        it 'should instantiate the WebSocket with the resolved url', ->
          expect(@WebSocket).to.have.been.calledWithNew
          expect(@WebSocket).to.have.been.calledWith 'ws:insecure.xxx:80/ws/v2'

    describe 'when constructed without resolveSrv', ->
      beforeEach ->
        @websocket = new EventEmitter
        @WebSocket = sinon.spy => @websocket

        options = resolveSrv: false, protocol: 'https', hostname: 'thug.biz', port: 123
        dependencies = {@request, @WebSocket}

        @sut = new Meshblu options, dependencies

      describe 'when connect is called', ->
        beforeEach 'making the request', (done) ->
          @sut.connect done
          @websocket.emit 'message', '["ready"]'

        it 'should instantiate the WebSocket with the resolved url', ->
          expect(@WebSocket).to.have.been.calledWithNew
          expect(@WebSocket).to.have.been.calledWith 'wss:thug.biz:123/ws/v2'

  describe '->close', ->
    describe 'with a connected client', ->
      beforeEach (done) ->
        @sut = new Meshblu {}, WebSocket: @WebSocket
        @sut.connect done
        @ws.emit 'message', '["ready"]'

      describe 'when called', ->
        beforeEach ->
          @sut.close()

        it 'should call close on the @ws', ->
          expect(@ws.close).to.have.been.called

    describe 'with a disconnected client', ->
      beforeEach ->
        @sut = new Meshblu {}, WebSocket: @WebSocket

      describe 'when called', ->
        it 'should not throw an error', ->
          expect(@sut.close).not.to.throw

  describe '->connect', ->
    describe 'when instantiated with node url params', ->
      beforeEach ->
        config = {
          hostname: 'localhost'
          port: 1234
          uuid: 'some-uuid'
          token: 'some-token'
        }
        @callback = sinon.spy()

        @sut = new Meshblu config, WebSocket: @WebSocket
        @sut.connect @callback

      afterEach ->
        @sut.close()

      it 'should instantiate a new ws', ->
        expect(@WebSocket).to.have.been.calledWithNew

      it 'should have been called with a formated url', ->
        expect(@WebSocket).to.have.been.calledWith 'ws:localhost:1234/ws/v2'

      describe 'when the WebSocket emits open', ->
        beforeEach ->
          @ws.emit 'open'

        it 'should send identity', ->
          expect(@ws.send).to.have.been.calledWith '["identity",{"uuid":"some-uuid","token":"some-token"}]'

      describe 'when the WebSocket emits ready', ->
        beforeEach ->
          @ws.emit 'message', '["ready",{}]'

        it 'should call the callback', ->
          expect(@callback).to.have.been.called

      describe 'when the WebSocket emits notready', ->
        beforeEach ->
          @ws.emit 'message', '["notReady",{"message":"Unauthorized"}]'

        it 'should call the callback with the error', ->
          expect(@callback.firstCall.args[0]).to.be.an.instanceOf Error
          expect(@callback.firstCall.args[0].message).to.deep.equal 'Unauthorized'

class WebSocket extends EventEmitter
  constructor: ->
    sinon.stub this, 'send'
    sinon.stub this, 'close'

  send: =>
  close: =>
