{-# LANGUAGE OverloadedStrings #-}
{-# LANGUAGE RecordWildCards   #-}

module DB where

import           Control.Exception               (bracket)
import           Data.ByteString.Internal        (ByteString)
import           Data.Maybe                      (listToMaybe)
import           Data.Text                       (Text)
import           Data.UUID                       (UUID)
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
  listItems <- query (PG.Only $ listId list) "SELECT * FROM items WHERE list_id = ?"


  return list { items = listItems }

insertList :: UUID -> PGTransaction (Maybe List)
insertList listId = do
  list <- query (PG.Only listId) "INSERT INTO lists VALUES (?, DEFAULT) RETURNING id, title, created_at, updated_at"
  return $ listToMaybe list

deleteList :: UUID -> PGTransaction ()
deleteList listId' = do
  _ <- execute (PG.Only listId') "DELETE FROM items WHERE list_id = ?"
  _ <- execute (PG.Only listId') "DELETE FROM lists WHERE id = ?"
  return ()

updateListTitle :: UUID -> Text -> PGTransaction (Maybe List)
updateListTitle id' newTitle = do
  list <- query (newTitle, id') "UPDATE lists SET title = ? WHERE id = ? RETURNING id, title, created_at, updated_at"
  return $ listToMaybe list

insertItem :: Item -> PGTransaction (Maybe Item)
insertItem Item{..} = do
  let queryStr = "INSERT INTO items VALUES (?, ?, ?, ?) RETURNING id, text, completed, list_id, created_at, updated_at"
  item <- query (itemId, text, completed, listsId) queryStr
  return $ listToMaybe item

updateItem :: Item -> PGTransaction (Maybe Item)
updateItem Item{..} = do
  let queryStr = "UPDATE items SET text = ?, completed = ?, list_id = ? WHERE id = ? RETURNING id, text, completed, list_id, created_at, updated_at"
  item <- query (text, completed, listsId, itemId) queryStr
  return $ listToMaybe item

deleteItem :: UUID -> PGTransaction ()
deleteItem itemId' = do
  _ <- execute (PG.Only itemId') "DELETE FROM items WHERE id = ?"
  return ()
