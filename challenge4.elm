import Char
import Html exposing (..)
import Html.Attributes as Attr exposing (..)
import Html.Events exposing (..)
import Http
import Json.Decode as Json exposing ((:=))
import String
import Task exposing (..)
import Set
import String exposing (join )


-- VIEW

view : String -> Result String (User) -> Html
view string result =
  let field =
        input
          [ placeholder "Please enter the GitHub username"
          , value string
          , on "input" targetValue (Signal.message query.address)
          , myStyle
          ]
          []

      messages =
        case result of
          Err msg ->
              [ div [ myStyle ] [ text msg ] ]

          Ok user ->
              [ div [ myStyle ] [ text user.name ]
              , div [ myStyle ] [ text <| "Knows the following programming languages: " ++ (join ", " user.languages)]
              , img  [ src user.avatar_url, imgStyle] []
              ]
  in
      div [] ((div [ myStyle ] [ text "GitHub Username" ]) :: field :: messages)



imgStyle : Attribute
imgStyle =
  style
    [ ("display", "block")
    , ("margin-left", "auto")
    , ("margin-right", "auto")
    ]


myStyle : Attribute
myStyle =
  style
    [ ("width", "100%")
    , ("height", "40px")
    , ("padding", "10px 0")
    , ("font-size", "2em")
    , ("text-align", "center")
    ]


-- WIRING

main =
  Signal.map2 view query.signal results.signal


query : Signal.Mailbox String
query =
  Signal.mailbox "evancz"


results : Signal.Mailbox (Result String (User)) 
results =
  Signal.mailbox (Err "")


port requests : Signal (Task x ())
port requests =
  query.signal
    |> Signal.map lookupUser 
    |> Signal.map (\task -> Task.toResult task `andThen` Signal.send results.address)


lookupUser : String -> Task String (User)
lookupUser query =
  succeed ("http://api.github.com/users/" ++ query)
  `andThen` (mapError (always "User not found :(") << Http.get decodeUser)
  `andThen` \userData ->
    (Http.get decodeLanguages userData.repos_url `onError` (\msg -> succeed [toString msg]))
  `andThen` \languages -> 
      let 
        user : User
        user =  { name = userData.name
                , avatar_url = userData.avatar_url
                , repos_url = userData.repos_url
                , languages = List.filter notEmpty <| Set.toList <| Set.fromList languages  
                }
      in succeed user 

notEmpty : String -> Bool
notEmpty s = not <| String.isEmpty s 

decodeLanguages : Json.Decoder (List (String))
decodeLanguages = (Json.list  <| Json.oneOf 
  [ (Json.at ["language"] Json.string)
  , (Json.succeed "")
  ])

type alias User = 
  {name: String
  , avatar_url: String
  , repos_url: String
  , languages: List String
  }


type alias UserData = 
  {name: String
  , avatar_url: String
  , repos_url: String
  }

decodeUser : Json.Decoder (UserData)
decodeUser = Json.object3 UserData
    ("name" := Json.string) 
    ("avatar_url" := Json.string)
    ("repos_url" := Json.string)
