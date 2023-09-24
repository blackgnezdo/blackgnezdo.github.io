import Text.Printf


-- The input downloaded with
--   yt-dlp -j --flat-playlist 'https://youtube.com/@TheCodingTrain'
-- The json then queried with:
--   jq '.id, .title'
main = do
  ls <- lines <$> readFile "/dev/stdin"
  let
    numbered = zip [0..] ls
    vids :: [String] = read . snd <$> filter (even . fst) numbered
    descs :: [String] = read . snd <$> filter (odd . fst) numbered
    subst '&' = "&amp;"
    subst '<' = "&lt;"
    subst c = [c]
    combine vid desc =
      let desc' = concatMap subst desc
      in unlines [
        "<html> <head> <title>" <> desc' <> "</title> </head> <body>",
        "<p>",
        "<iframe width='560' height='315' src='https://www.youtube-nocookie.com/embed/" <> vid <>
          "' frameborder='0' allow='accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture' allowfullscreen>",
          "</iframe></p>",
          "<p>" <> desc' <> "</p></body></html>"
        ]
    files = zip [(0::Int)..] $ zipWith combine vids descs
  flip mapM_ files $ \(num, cont) -> writeFile (printf "/tmp/ct%04d.html" num) cont
