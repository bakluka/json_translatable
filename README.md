# JSON Translatable

[![Gem Version](https://badge.fury.io/rb/json_translatable.svg)](https://badge.fury.io/rb/json_translatable.svg)  
[![License: MIT](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

A I18n Rails gem that allows storing and querying translations for ActiveRecord models in a single JSON/JSONB column.

---

## Table of Contents

- [Features](#features)
- [Installation](#installation)
- [Configuration](#configuration)
- [Usage](#usage)
  - [1. Model Setup](#1-model-setup)
  - [2. Generating the Migration](#2-generating-the-migration)
  - [3. Validations](#3-validations)
  - [4. Querying Translations](#4-querying-translations)
  - [5. Working with Translations in Code](#5-working-with-translations-in-code)
  - [6. Strong Parameters](#6-strong-parameters)
- [Development](#development)
- [Contributing](#contributing)
- [License](#license)

## Features

- **Single Column Translations**: Store all locale-specific fields in a single JSON column.
- **Customizable Locales**: Default locales are pulled from `I18n.available_locales`, but you can override them on a per-model or global basis.
- **Validation Helpers**: Validate presence, length, format, or pass a block for translated fields
- **Query Scopes**: Perform database queries on translated content.
- **Strong Parameter Support**: Helper for generating permitted parameter lists for translations in controllers.


## Requirements

- **Rails** >= 7.0
- **PostgreSQL** >= 9.4 *or*
- **MySQL** >= 5.7.9 *or*
- **SQLite** >= 3.38.0 (>= 3.9.0 if compiled with SQLITE_ENABLE_JSON1 enabled)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'json_translatable'
```

Then execute:

```bash
bundle install
```

Or simply run:

```bash
bundle add json_translatable
```

## Configuration

You can customize default settings for all models that include **Translatable** concern.

Create an initializer (e.g., `config/initializers/translatable.rb`) and configure:

- **`default_column_name`** (`Symbol`): Override the default JSON/JSONB column name used to store translations.
- **`default_locales`** (`Proc`): Provide a Proc/lambda that returns an array of locale symbols. By default, this uses `I18n.available_locales`.

```ruby
Translatable.configure do |config|
  # Default column name for storing translations (default: :translations)
  config.default_column_name = :i18n_translations

  # Default locales to support on attached models (default: -> { I18n.available_locales })
  config.default_locales = -> { [:en, :es, :fr] }
end
```

## Usage

### 1. Model Setup

In any ActiveRecord model, include the `Translatable` concern and declare which fields should be translatable. Optionally, specify custom locales or a custom column:

```ruby
class Article < ApplicationRecord
  include Translatable

  # Use default locales from I18n.available_locales, default column :translations
  translatable :title, :content

  # Or override locales and column name:
  translatable :title, :content, locales: [:en, :es], column: :i18n_data
end
```

### 2. Generating the Migration

Before using translations, you need to add a JSON/JSONB column to your model's table.

Generate a migration file, e.g.:

```bash
rails generate migration AddTranslationsToArticles
```

Edit the migration to include:

```ruby
class AddTranslationsToArticles < ActiveRecord::Migration[8.0]
  def change
    # For PostgreSQL:
    add_column :articles, :translations, :jsonb, default: {}, null: false

    # For MySQL:
    add_column :articles, :translations, :json, null: false

    # For SQLite:
    add_column :articles, :translations, :json, default: {}, null: false
  end
end
```

If you plan to run database queries against the translations and are running PostgreSQL, you can add a GIN index to the translations column to greatly improve the query performance, e.g.:

```ruby
class AddIndexToArticleTranslations < ActiveRecord::Migration[8.0]
  def change
    add_index :articles, :translations, using: :gin, opclass: :jsonb_path_ops
  end
end
```
*MySQL and SQLite have no direct equivalent to PostgreSQL’s GIN index; if you’re concerned with query performance, you can create generated columns or expression indexes on the specific JSON paths you query.*


Run migrations:

```bash
rails db:migrate
```

### 3. Validations

You can validate translated fields similarly to standard ActiveRecord validations, but using `validates_translation`:

```ruby
class Article < ApplicationRecord
  include Translatable
  translatable :title, :subtitle, :content, locales: [:en, :es]

  # Validate presence of title in all locales
  validates_translation :title, presence: true

  # Validate length of content only for English locale
  validates_translation :content, length: { minimum: 50 }, locales: [:en]

  # Validate format with custom regex (e.g., subtitle must start with a capital letter)
  validates_translation :subtitle, presence: true, format: { with: /\A[A-Z]/ }, locales: [:en, :es]

  # Custom validation logic using a block
  validates_translation :content, locales: [ :es ] do |record, locale, field, value|
    if locale == :es && value.present? && value.split(" ").size < 10
      record.errors.add("translations", "must have at least 10 words")
    end
  end
end
```

- `validates_translation *fields, presence: true, length: { ... }, format: { ... }, locales: [...], &block`
  - `fields`: Fields defined in `translatable`.
  - `:presence`, `:length`, `:format` - behave like standard validator options.
  - `:locales` (optional): Limit validation to a subset of locales. Default is all `translatable_locales`.
  - `&block`: Provide a block to enforce custom logic. Receives `(record, locale, field, value)`.

`Translatable` will automatically add validation errors when trying to save a record with locales and/or keys not specified in the `translatable` method


#### ActiveModel::Errors caveat

```ActiveModel::Error``` requires that errors are added to an existing Rails attribute - all ```Translatable``` errors are added to the ```translations``` attribute (or whatever your translations column is named). 

When you need to find errors for specific languages/fields, the ```translation_key``` value is present in the error options, e.g.:

```ruby
article.valid?
=> false
article.errors.first
=> #<ActiveModel::Error attribute=translations, type=blank, options={translation_key: "translations.en.title"}>
article.errors.first.options[:translation_key]
=> "translations.en.title"
```

### 4. Querying Translations

To query records based on translated content, use `where_translations`:

```ruby
# Find all articles where title in any locale equals "Welcome"
Article.where_translations({ title: 'Welcome' })

# Limit search to specific locales (e.g., only Spanish)
Article.where_translations({ title: 'Bienvenido' }, locales: [:es])

# Case-insensitive search by default
Article.where_translations({ content: 'rails' })

# Case-sensitive search
Article.where_translations({ content: 'Rails' }, case_sensitive: true)
```

`where_translations` returns an ActiveRecord relations so it can be chained as any other regular scope



### 5. Working with Translations in Code

#### Accessing the Translation Object

Each translatable model exposes a `translate` instance method, returning a lightweight translation object:

```ruby
article = Article.find(1)

# Get a translation object for the current I18n.locale (e.g., :en)
en_translation = article.translate
# <Translatable::ArticleTranslation title: "My English Title", content: "My English Content", locale: :en>
en_translation.title   #=> "My English Title"
en_translation.content #=> "My English Content"
en_translation.locale  #=> :en

# Get a translation for a specific locale
es_translation = article.translate(:es)
# <Translatable::ArticleTranslation title: "Mi Título en Español", content: "Mi Contenido en Español", locale: :es>
es_translation.title   #=> "Mi Título en Español"
es_translation[:content] #=> "Mi Contenido en Español"
```

The translation object behaves like a simple struct with:

- Attribute readers for each translatable field.
- Enumerable: iterate through `(field, value)` pairs (excluding `:locale`).
- `[key]` access to arbitrary fields
- `to_h` to return a hash of `{ field_name => value, ... }`.
- `keys` and `values` helpers.
- `empty?`, `size`, `length`.

#### Setting Translations

Since translations live in a JSON column, assign a nested hash directly:

```ruby
article = Article.new

# Assign translations manually
article.translations = {
  'en' => { 'title' => 'Hello', 'content' => 'Content in English' },
  'es' => { 'title' => 'Hola',  'content' => 'Contenido en Español' }
}

article.save!
```

Alternatively, update individual nested values:

```ruby
article = Article.find(1)
data = article.translations

data['fr']['title']   = 'Bonjour'
data['fr']['content'] = 'Contenu en Français'

article.translations = data
article.save!
```

#### Form example

`translatable` concern adds `translatable_locales` and `translatable_fields` methods to the model class. You can use those methods to create a simple form for your translations, e.g.:

```erb
<%= form_for @article do |f| %>
  <% Article.translatable_locales.each do |locale| %>
    <%= f.fields_for "translations[#{locale}]", f.object.translate(locale) do |ff| %>
      <% Article.translatable_fields.each do |field| %>
        <%= ff.label field %>
        <%= ff.text_field field %>
      <% end %>
    <% end %>
  <% end %>
<% end %>
```

### 6. Strong Parameters

In controllers, permit translated fields easily:

```ruby
class ArticlesController < ApplicationController
  def create
    @article = Article.new(article_params)
    if @article.save
      redirect_to @article, notice: 'Article was successfully created.'
    else
      render :new
    end
  end

  private

  def article_params
    params.require(:article).permit(:user_id, translations: Article.translations_permit_list)
  end
end
```

**`Model.translations_permit_list`** returns a hash suitable for `permit` in strong parameters:
  ```ruby
  # Example:
  Article.translations_permit_list
  # => {
  #     "en" => ["title", "content"],
  #     "es" => ["title", "content"],
  #     ...
  # }
  ```

## License

This project is licensed under the **MIT License**. See the [LICENSE](LICENSE) file for details.

