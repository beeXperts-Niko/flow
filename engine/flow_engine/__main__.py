from flow_engine.server import self_test, serve


def main() -> None:
    import sys

    if "--self-test" in sys.argv:
        self_test()
        return
    serve()


if __name__ == "__main__":
    main()
