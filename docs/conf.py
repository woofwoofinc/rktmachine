import sphinx_bootstrap_theme

needs_sphinx = '1.6.1'

project = u'RktMachine'
copyright = u'2017, Woof Woof, Inc.'
author = u'Woof Woof, Inc.'

version = '1.0-rc1'
release = '1.0-rc1'

templates_path = ['_templates']
exclude_patterns = ['_build']

source_suffix = '.rst'
master_doc = 'index'

language = None
pygments_style = 'sphinx'

extensions = [
    'sphinx.ext.githubpages',
]

def setup(app):
  app.add_stylesheet("woofwoofinc.css")


# -- Options for HTML output ----------------------------------------------

html_theme = 'bootstrap'
html_theme_path = sphinx_bootstrap_theme.get_html_theme_path()

html_title = project

html_show_sourcelink = False
html_show_sphinx = False
html_show_copyright = False

html_theme_options = {
    'navbar_site_name': 'Contents',
    'navbar_pagenav': False,
    'globaltoc_depth': 2,
    'navbar_class': 'navbar navbar-inverse',
    'navbar_fixed_top': 'true',
    'bootswatch_theme': 'simplex',
}

html_static_path = ['assets']
