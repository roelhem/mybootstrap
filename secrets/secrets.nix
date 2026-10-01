let

  keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINwkGxM1edPvK6Plln/Qio2yWudaSPTx94wbgE6SGx7Y"
    "age103wd5xtna4dqkfnzq97d0kutjuclvuf0ypqnu9yqxkl8rthr3ypqt0n7se"
    "age1fido2-hmac1qqp9s2p34zmca9n606m88ahx7pulhlyqdgjhgwye88nqyy09wd30qdcpnfulwkqeyrgcw8lfa7t2lpt2e8s7hd7ryv6ulpn0u2pvzcw9zth22frttvpgttqsjznx6qt7c29clt8nvvavagrrruwrm7a8rqh3gs0krh6qettgut3gnepfk4gzn43tunsgqekk0s2a5sjtjcqm8au5dhwt3ud4l2q5c3wntq5pygp8rpfvn8rn7n7p2lac9xy9wrrx0nyl0vzs8t2asj4d3zq4kakfn0dyhm9qs4yfft0cny8y739z6ekmumt6mr4anp6q6sc6qp"
  ];

in

{
  "bootstrap-identity.age".publicKeys = keys;
  "bootstrap-nix-config.age".publicKeys = keys ++ [
    (builtins.readFile ./bootstrap-identity.pub)
  ];
}
