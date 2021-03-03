---
layout: post
status: publish
published: true
title: Wordpress - auf mehrere Seiten posten
author:
  display_name: cheesy
  login: cheesy
  email: christine@cheesy.at
  url: http://www.cheesy.at/
author_login: cheesy
author_email: christine@cheesy.at
author_url: http://www.cheesy.at/
wordpress_id: 11866
wordpress_url: http://www.cheesy.at/?p=11866
date: '2010-08-30 13:16:53 +0100'
date_gmt: '2010-08-30 11:16:53 +0100'
categories:
- Spiel
- Programmieren
- wordpress
- posts
- blog
- workaround
- weblog
comments: []
---
<!--:de-->Ich habe heute wieder einmal Stunden meines Lebens vergeudet nur um eine simple aber leider nicht supportete Sache in Wordpress zu machen. Für eine Blog-Seite habe ich unbedingt das Feature benötigt, dass man statt auf die Hauptseite zu posten, auf zwei unterschiedlichen Seiten unterschiedliche Posts anzeigt. In meinem Fall sollte das Menü folgendermaßen aussehen: _News - FAQ - About_ - mehr nicht. Unter News sollten Neuigkeiten gepostet werden, unter FAQ ... naja, eh klar, oder?Nach mehreren erfolglosen und deprimierenden Versuchen habe ich einen Workaround über Kategorien gefunden und muss mich mit einer Page zusätzlich begnügen, in die man alle Posts hineindumpen kann, also sieht mein Menü jetzt so aus: _News - FAQ - About - All Posts_. Schritt für Schritt:
1. Das Plugin "Page Links To" installieren und aktivieren.
2. Kategorien erzeugen, mit dem Namen der Pages, die später Blogposts enthalten sollen.
3. Pages mit den gewünschten Namen erzeugen die Blogposts enthalten sollen und mit dem "Page Links To" Plugin auf die eben erstellten Kategorien verlinken. (`http:///?cat=`)
4. Eine zusätzliche Page mit so einem wohlklingenden Namen wie "All Posts" oder was auch immer anlegen und sie möglichst nach hinten sortieren.
5. Im Header Template (header.php) des Themes die zweite Zeile des folgenden Codestücks löschen oder auskommentieren, um die Homepage wegzubekommen:
`
Home
`
6. _Settings - Reading Front page displays_ auf "A static page" setzen und als Front page die erste Seite (in meinem Fall _News_) und die Posts page: auf "All posts" oder welchen Namen ihr für den Dump gewählt habt setzen.
7. Jetzt müssen nur noch die Posts in die richtigen Kategorien geschaufelt werden und schon scheinen sie auf den richtigen Seiten auf...
<!--:--><!--:en-->Today I lost some precious hours of my life to do a simple but unfortunately unsupported thing with wordpress. For a blog-page I desperately needed the feature to post to more than one page! In my case the main menu should have looked like this: _News - FAQ - About_ - nothing more. Under News I needed to post some in-character news regarding a rpg I'm in, under FAQ I needed to post the out-of-character news and help for my fellow players. After several unsuccessful depressing tries I found a workaround over Categories and I had to add one more page where I could dump all the posts. Finally my menu looks like this: _News - FAQ - About - All Posts_. Here's the step-by-step:
  1. Intall and activate the plugin "Page Links To".
  2. Create Categories with the names of the pages you want to have blogposts in.
  3. Create Pages with the preferred names for your multiple blogs and link it to the desired categories using the "Page Links To" plugin. (`http:///?cat=`)
  4. Make one additional page with a creative name like "All Posts" or whatever you want and sort it to the very back of your pages list.
  5. Go to the header template(header.php) of your theme and delete the second line of the following code in this file to get rid of your homepage:
`
Home
`
  6. Set _Settings - Reading Front page displays_ to "A static page" and select your preferred page as Front page (in my case _News_) and select your dump as Posts page.
  7. Now you only have to add the correct categories to your posts and they will appear under the correct pages.
<!--:-->
