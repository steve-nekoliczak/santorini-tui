module Gameplay
  ( main
  ) where

import Control.Monad.IO.Class (liftIO)
import Control.Monad.Trans.State (StateT, get, put, runStateT)
import Prelude
import Text.Read (readMaybe)

import GameEngine

data GameState =
    PlaceWorkers
  | MoveWorker  { player :: Player }
  | BuildUp     { player :: Player, worker :: Worker }
  | GameOver
  deriving (Show, Eq)

type BaseStateT = StateT GameState IO
type GameStateT = BaseStateT (Either BoardError Board)

main :: IO ()
main = do
  putStrLn "Starting new game of Santorini!"
  let startGame = gameplayLoopT emptyBoard
  let initialState = PlaceWorkers
  newGame <- runStateT startGame initialState
  print $ fst newGame
  return ()

gameplayLoopT :: Board -> GameStateT
gameplayLoopT board = do
  liftIO $ print board

  state' <- get

  boardAfterAction <-
        case state' of
          PlaceWorkers                      -> placeNextWorkerT board
          MoveWorker targetPlayer           -> moveWorkerT targetPlayer board
          BuildUp targetPlayer targetWorker -> buildUpT targetPlayer targetWorker board
          GameOver                          -> return $ Right board

  stateAfterAction <- get

  case boardAfterAction of
    Left errorMessage   -> liftIO (print errorMessage) >> gameplayLoopT board
    Right newBoard      ->
      case stateAfterAction of
        GameOver        -> return boardAfterAction
        _else           -> gameplayLoopT newBoard

placeNextWorkerT :: Board -> GameStateT
placeNextWorkerT board = do
  targetPosition <- case nextWorkerToPlace board of
    Just workerToPlace  -> readPosition $ "Please place " ++ show workerToPlace ++ " character"
    Nothing             -> return Nothing

  case targetPosition of
    Just position       -> do
      let boardAfterAction = placeNextWorker position board

      case boardAfterAction of
        Left _            -> put PlaceWorkers
        Right newBoard    ->
          case nextWorkerToPlace newBoard of
            Nothing       -> put $ MoveWorker BluePlayer
            Just _        -> put PlaceWorkers

      return boardAfterAction
    Nothing       -> return (Left $ AllWorkersPlacedError "All workers have been placed.")

moveWorkerT :: Player -> Board -> GameStateT
moveWorkerT playerToMove board = do
  workerToMove <- readWorker $ "Select a character for " ++ show playerToMove ++ ": " ++ show (workersForPlayer playerToMove)
  targetPosition <- readPosition $ "Select target position for " ++ show workerToMove

  case (workerToMove, targetPosition) of
    (Nothing, _)                    -> return (Left $ InvalidWorkerError "Please select a valid worker.")
    (Just _, Nothing)               -> return (Left $ InvalidPositionError "Please select a valid position.")
    (Just worker', Just position)   -> do
      let boardAfterAction = moveWorker worker' position board

      case boardAfterAction of
        Left _            -> put $ MoveWorker playerToMove
        Right _           -> put $ BuildUp playerToMove worker'

      return boardAfterAction

buildUpT :: Player -> Worker -> Board -> GameStateT
buildUpT playerToBuild workerToBuild board = do
  targetPosition <- readPosition $ "Select target position to build for " ++ show workerToBuild

  case targetPosition of
    Just position       -> do
      let boardAfterAction = buildUp workerToBuild position board

      case boardAfterAction of
        Left _            -> put $ BuildUp playerToBuild workerToBuild
        Right _           -> put $ MoveWorker $ nextPlayer playerToBuild

      return boardAfterAction
    Nothing       -> return (Left $ InvalidPositionError "Please select a valid position.")

readPosition :: String -> BaseStateT (Maybe Position)
readPosition message = do
  positionInput <- readInput message
  return (readMaybe positionInput :: Maybe Position)

readWorker :: String -> BaseStateT (Maybe Worker)
readWorker message = do
  workerInput <- readInput message
  return (readMaybe workerInput :: Maybe Worker)

readInput :: String -> BaseStateT String
readInput message = do
  liftIO $ print message
  liftIO getLine
