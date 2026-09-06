import os
from setuptools import setup, find_packages


def read_requirements():
    with open("requirements.txt", "r") as f:
        reqs = [line.strip() for line in f if line.strip() and not line.startswith("#")]
    # python-ldap needs OpenLDAP headers and a C compiler at install time. The app
    # already treats it as optional (see ldap_util.py), so keep it out of the core
    # requirements and expose it as the [ldap] extra.
    core = [r for r in reqs if not r.lower().startswith("python-ldap")]
    ldap = [r for r in reqs if r.lower().startswith("python-ldap")]
    return core, ldap


core_requirements, ldap_requirements = read_requirements()

setup(
    name="fireshare",
    version=os.environ.get("FIRESHARE_VERSION", "1.7.9"),
    packages=find_packages(),
    # The wheel carries the built web client, the alembic migrations and the
    # gunicorn config, copied into the package by scripts/build_wheel.sh.
    include_package_data=True,
    entry_points={
        "console_scripts": [
            "fireshare=fireshare.cli:cli"
        ]
    },
    install_requires=core_requirements,
    extras_require={"ldap": ldap_requirements},
)
