{-# LANGUAGE OverloadedStrings #-}

module DB where

import           Control.Exception               (bracket)
import           Data.ByteString.Internal        (ByteString)
import           Data.Maybe                      (listToMaybe)
import           Data.Text                       (Text)
import qualified Database.PostgreSQL.Simple      as PG
import           Database.PostgreSQL.Transaction
import           Types


-- EXECUTION

runDB :: PGTransaction a -> IO a
runDB action =
  withConnection $ \connection ->
                     runPGTransactionIO action connection

withConnection :: (PG.Connection -> IO a) -> IO a
withConnection =
  bracket (PG.connectPostgreSQL connectionString) PG.close

connectionString :: ByteString
connectionString = "host=localhost port=5432 dbname=shopshare_dev connect_timeout=10"


-- QUERIES

selectAllLists :: PGTransaction [List]
selectAllLists = do
  lists <- query_ "SELECT * FROM lists"
  mapM selectItemsForList lists

selectItemsForList :: List -> PGTransaction List
selectItemsForList list = do
  let queryStr = "SELECT * FROM items WHERE list_id = (?)"
  listItems <- query (PG.Only $ listId list) queryStr
  return list { items = listItems }

insertList :: Text -> PGTransaction (Maybe List)
insertList title' = do
  list <- query (PG.Only title') "INSERT INTO lists VALUES (DEFAULT, ?) RETURNING id, title"
  return $ listToMaybe list
