module App.Events where

import App.Config (MySettings)
import App.Events.Post (Event(..), State(..), foldp) as EPost
import App.Routes (Route(..), match)
import App.State (State(..))
import Control.Monad.Aff (Aff)
import Control.Monad.Eff.Class (liftEff)
import Control.Monad.Eff.Exception (EXCEPTION)
import Control.Monad.Except.Trans (ExceptT, runExceptT)
import Control.Monad.Reader.Trans (ReaderT, runReaderT)
import DOM (DOM)
import DOM.Event.Event (preventDefault)
import DOM.HTML (window)
import DOM.HTML.History (DocumentTitle(..), URL(..), pushState)
import DOM.HTML.Types (HISTORY)
import DOM.HTML.Window (history)
import Data.Either (Either(..))
import Data.Foreign (toForeign)
import Data.Maybe (Maybe(Just))
import Database.Persist.Class.PersistEntity (Entity, Key(..))
import Model.User (User)
import Network.HTTP.Affjax (AJAX)
import Prelude (bind, discard, map, pure, ($), (#), (<$>), (=<<))
import Prim (Array, String)
import Pux (EffModel, mapEffects, mapState, noEffects, onlyEffects)
import Pux.DOM.Events (DOMEvent)
import Servant.PureScript.Affjax (AjaxError)
import ServerAPI (getPosts, getPostsById, getUserGetByName)
import Signal.Channel (CHANNEL)

data Event = PageView Route
           | Navigate String DOMEvent
           | ChildPostEvent EPost.Event
           | ReceiveUser (Entity User)
           | RequestUser
           | ReportError AjaxError

foldp :: forall fx. Event -> State -> EffModel State Event (ajax :: AJAX, dom:: DOM, history :: HISTORY | fx)
foldp (PageView RPosts) (State st) =
  runEffectActions
  (State st {route = RPosts})
  [ChildPostEvent <$> (EPost.ReceivePosts <$> getPosts)]
foldp (PageView (RPost postid)) (State st) =
  runEffectActions
  (State st {route = RPost postid})
  [ChildPostEvent <$> EPost.ReceivePost <$> getPostsById (Key postid)]
foldp (PageView route) (State st) =
  noEffects $ State st {route = route}
foldp (Navigate url ev) state =
  onlyEffects state [
    liftEff do
      preventDefault ev
      h <- history =<< window
      pushState (toForeign {}) (DocumentTitle "") (URL url) h
      pure $ Just $ PageView (match url)
    ]
foldp (ChildPostEvent e) (State st) =
  let EPost.State pc = st.postChild in
  EPost.foldp e (EPost.State pc {settings = st.settings})
    # mapEffects (\ev -> event ev)
    # mapState \sb -> State st { postChild = sb }
  where event (EPost.PostSubmited _) = PageView RPosts
        event ev = ChildPostEvent ev
foldp (ReceiveUser user) (State st) =
  noEffects $ State st {user = Just user}
foldp (RequestUser) state = runEffectActions state [ReceiveUser <$> getUserGetByName "Alice"]
foldp (ReportError err) (State st) =
  noEffects $ State st {lastError = Just err}

type APIEffect eff = ReaderT MySettings (ExceptT AjaxError (Aff ( ajax :: AJAX, channel :: CHANNEL, exception :: EXCEPTION | eff)))

runEffectActions :: forall fx. State -> Array (APIEffect (fx) Event) -> EffModel State Event (ajax :: AJAX | fx)
runEffectActions (State st) effects = { state : State st, effects : map (runEffect st.settings) effects }

runEffect :: forall fx. MySettings -> APIEffect (fx) Event -> Aff (channel :: CHANNEL, ajax :: AJAX, exception :: EXCEPTION | fx) (Maybe Event)
runEffect settings m = do
    er <- runExceptT  $ runReaderT m settings
    case er of
      Left err -> pure $ Just $ ReportError err
      Right v -> pure $ Just $ v
