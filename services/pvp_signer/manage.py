"""Local-only administrative commands. Run as the pvp-signer service user."""
import argparse
import json
import os
from service import Service, Settings


def main():
    os.umask(0o077)
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--database', default=os.environ.get('PVP_DATABASE', '/var/lib/pvp-signer/state.db'))
    commands = parser.add_subparsers(dest='command', required=True)
    create = commands.add_parser('create-invite')
    create.add_argument('--ttl', type=int, default=7 * 86400)
    commands.add_parser('list-invites')
    commands.add_parser('revoke-invite').add_argument('invite_hash')
    commands.add_parser('revoke-player').add_argument('player_id')
    args = parser.parse_args()
    service = Service(args.database, Settings())
    try:
        if args.command == 'create-invite':
            result = {'invite': service.create_invite(args.ttl)}
        elif args.command == 'list-invites':
            result = service.list_invites()
        elif args.command == 'revoke-invite':
            service.revoke_invite(args.invite_hash); result = {'ok': True}
        else:
            service.revoke(args.player_id); result = {'ok': True}
        print(json.dumps(result))
    finally:
        service.close()

if __name__ == '__main__': main()
